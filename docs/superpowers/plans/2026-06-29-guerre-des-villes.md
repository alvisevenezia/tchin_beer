# La guerre des villes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real-time per-city leaderboard ("La guerre des villes") with *Aujourd'hui* / *Cette semaine* windows to Tchin.beer.

**Architecture:** Date-stamped Redis sorted sets (`rank:day:<date>`, `rank:week:<isoweek>` in Europe/Paris) give real-time ranking with automatic daily/weekly reset by key naming (no cron). Postgres is the source of truth — keys rebuild from the `pintes` table on cold start. Posting a pinte bumps the ZSETs and publishes a lightweight `rankings_changed` SSE signal; the Flutter screen debounce-refetches `GET /rankings`.

**Tech Stack:** FastAPI + SQLAlchemy async + Redis (asyncio) backend; Flutter + Riverpod frontend; pytest (real PG+Redis) + flutter_test.

## Global Constraints

- **Timezone for windows:** `Europe/Paris` (via `zoneinfo.ZoneInfo`).
- **Redis** runs with `decode_responses=True` (members/scores come back as `str`/`float`).
- **No git repo:** this project is not under git. Replace every "Commit" step with the task's **Verify** step — do not run `git`.
- **Brand tokens (Flutter `AppTokens`):** cream `#FFF4E0`, foam `#FFFBF2`, ink `#2A1A0D`, amber `#F4A722`, coral `#FF6A3D`, sky `#1AA3D6`, rail `#ECDCBF`, muted `#9A865F`. Medal-2 fill is `#FF8A3D` (not a token).
- **Rank is 1-based in the API** (Redis `ZREVRANK` is 0-based — add 1).
- **fr-FR number formatting:** reuse `formatCountFr` from `app/lib/util/format.dart`.
- Backend tests run from `back/` and require Postgres + Redis up (see `back/tests/conftest.py`). Flutter commands run from `app/`.

---

### Task 1: Pure ranking helpers (normalize, period keys, window start)

**Files:**
- Create: `back/app/domain/rankings.py`
- Test: `back/tests/test_rankings.py`

**Interfaces:**
- Produces: `normalize_city(s: str) -> str`, `period_keys(now: dt.datetime) -> tuple[str, str]` (returns `(day_key, week_key)`), `window_start(period: str, now: dt.datetime) -> dt.datetime` (aware UTC), `now_utc() -> dt.datetime`.

- [ ] **Step 1: Write the failing test**

```python
# back/tests/test_rankings.py
import datetime as dt

from app.domain import rankings as r


def test_normalize_city_strips_accents_case_space():
    assert r.normalize_city("  Saint-Étienne ") == "saint-etienne"
    assert r.normalize_city("PARIS") == "paris"
    assert r.normalize_city("Le  Mans") == "le mans"
    assert r.normalize_city("   ") == ""


def test_period_keys_paris_timezone():
    # 2026-06-29 is a Monday (ISO week 27).
    now = dt.datetime(2026, 6, 29, 1, 30, tzinfo=dt.timezone.utc)  # 03:30 Paris
    day, week = r.period_keys(now)
    assert day == "rank:day:2026-06-29"
    assert week == "rank:week:2026-W27"


def test_period_keys_rolls_over_at_paris_midnight():
    # 22:30 UTC on 2026-06-29 == 00:30 Paris on 2026-06-30.
    now = dt.datetime(2026, 6, 29, 22, 30, tzinfo=dt.timezone.utc)
    day, _ = r.period_keys(now)
    assert day == "rank:day:2026-06-30"


def test_window_start_week_is_paris_monday_midnight_utc():
    now = dt.datetime(2026, 7, 1, 10, 0, tzinfo=dt.timezone.utc)  # Wed of W27
    start = r.window_start("week", now)
    # Monday 2026-06-29 00:00 Paris == 2026-06-28 22:00 UTC.
    assert start == dt.datetime(2026, 6, 28, 22, 0, tzinfo=dt.timezone.utc)
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `back/`): `pytest tests/test_rankings.py -v`
Expected: FAIL — `ModuleNotFoundError`/`AttributeError` (rankings helpers undefined).

- [ ] **Step 3: Write minimal implementation**

```python
# back/app/domain/rankings.py
import datetime as dt
import unicodedata
from zoneinfo import ZoneInfo

from sqlalchemy import text

TZ = ZoneInfo("Europe/Paris")
DAY_TTL = 48 * 3600
WEEK_TTL = 9 * 86400
DISPLAY_KEY = "city:display"


def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def normalize_city(s: str) -> str:
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    return " ".join(s.casefold().split())


def period_keys(now: dt.datetime) -> tuple[str, str]:
    local = now.astimezone(TZ)
    iso = local.isocalendar()
    return (
        f"rank:day:{local:%Y-%m-%d}",
        f"rank:week:{iso.year}-W{iso.week:02d}",
    )


def window_start(period: str, now: dt.datetime) -> dt.datetime:
    local = now.astimezone(TZ)
    day = local.date()
    if period == "week":
        day = day - dt.timedelta(days=local.weekday())
    start_local = dt.datetime.combine(day, dt.time(0, 0), tzinfo=TZ)
    return start_local.astimezone(dt.timezone.utc)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_rankings.py -v`
Expected: PASS (4 tests).

- [ ] **Step 5: Verify** — `pytest tests/test_rankings.py -v` green; no git commit (repo isn't git).

---

### Task 2: Redis ranking operations (rebuild / ensure_built / bump / top_cities / city_rank)

**Files:**
- Modify: `back/app/domain/rankings.py`
- Test: `back/tests/test_rankings.py` (append)

**Interfaces:**
- Consumes (Task 1): `normalize_city`, `period_keys`, `window_start`, `now_utc`, `DAY_TTL`, `WEEK_TTL`, `DISPLAY_KEY`.
- Produces:
  - `async rebuild(session, redis, period, now=None) -> str`
  - `async ensure_built(session, redis, period, now=None) -> str`
  - `async bump(session, redis, city, now=None) -> None`
  - `async top_cities(session, redis, period, limit, now=None) -> list[dict]` — dicts `{key, name, count, rank}`
  - `async city_rank(session, redis, period, city, now=None) -> dict | None` — dict `{key, name, count, rank}`

- [ ] **Step 1: Write the failing test**

```python
# back/tests/test_rankings.py (append)
import pytest


async def _post(client, headers, seed):
    files = {"photo": ("p.jpg", b"\xff\xd8\xff\xe0" + seed, "image/jpeg")}
    return await client.post("/pintes", headers=headers, files=files)


async def _account(client, pseudo, city):
    res = await client.post("/auth/device", json={"pseudo": pseudo, "city": city})
    return {"Authorization": f"Bearer {res.json()['device_token']}"}


@pytest.mark.asyncio
async def test_top_cities_orders_and_aggregates(client, redis, session):
    lyon = await _account(client, "L1", "Lyon")
    lyon2 = await _account(client, "L2", "lyon")  # même ville, casse différente
    paris = await _account(client, "P1", "Paris")
    await _post(client, lyon, b"a")
    await _post(client, lyon2, b"b")
    await _post(client, paris, b"c")

    from app.domain import rankings as r
    top = await r.top_cities(session, redis, "day", 10)
    assert top[0]["key"] == "lyon" and top[0]["count"] == 2 and top[0]["rank"] == 1
    assert top[0]["name"] in ("Lyon", "lyon")
    assert top[1]["key"] == "paris" and top[1]["count"] == 1 and top[1]["rank"] == 2


@pytest.mark.asyncio
async def test_city_rank_returns_none_for_silent_city(client, redis, session):
    lyon = await _account(client, "L1", "Lyon")
    await _post(client, lyon, b"a")
    from app.domain import rankings as r
    assert (await r.city_rank(session, redis, "day", "Lyon"))["rank"] == 1
    assert await r.city_rank(session, redis, "day", "Nantes") is None


@pytest.mark.asyncio
async def test_rebuild_recovers_after_flush(client, redis, session):
    lyon = await _account(client, "L1", "Lyon")
    await _post(client, lyon, b"a")
    await redis.flushdb()
    from app.domain import rankings as r
    top = await r.top_cities(session, redis, "day", 10)
    assert top and top[0]["key"] == "lyon" and top[0]["count"] == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_rankings.py -k "top_cities or city_rank or rebuild" -v`
Expected: FAIL — `AttributeError: module 'app.domain.rankings' has no attribute 'top_cities'`.

- [ ] **Step 3: Write minimal implementation**

```python
# back/app/domain/rankings.py (append)

def _key_ttl(period: str, now: dt.datetime) -> tuple[str, int]:
    day, week = period_keys(now)
    return (week, WEEK_TTL) if period == "week" else (day, DAY_TTL)


async def rebuild(session, redis, period: str, now: dt.datetime | None = None) -> str:
    now = now or now_utc()
    key, ttl = _key_ttl(period, now)
    start = window_start(period, now)
    rows = (
        await session.execute(
            text(
                "SELECT a.city, COUNT(*) AS n FROM pintes p "
                "JOIN accounts a ON a.id = p.account_id "
                "WHERE p.created_at >= :start AND p.status = 'active' "
                "GROUP BY a.city"
            ),
            {"start": start},
        )
    ).all()
    agg: dict[str, int] = {}
    display: dict[str, str] = {}
    for city, n in rows:
        k = normalize_city(city)
        if not k:
            continue
        agg[k] = agg.get(k, 0) + n
        display.setdefault(k, city)
    pipe = redis.pipeline()
    pipe.delete(key)
    if agg:
        pipe.zadd(key, agg)
        pipe.expire(key, ttl)
        pipe.hset(DISPLAY_KEY, mapping=display)
    await pipe.execute()
    return key


async def ensure_built(session, redis, period: str, now: dt.datetime | None = None) -> str:
    now = now or now_utc()
    key, _ = _key_ttl(period, now)
    if not await redis.exists(key):
        await rebuild(session, redis, period, now)
    return key


async def bump(session, redis, city: str, now: dt.datetime | None = None) -> None:
    k = normalize_city(city)
    if not k:
        return
    now = now or now_utc()
    # The pinte is already committed to Postgres before bump() is called, so a
    # rebuild already counts it; only ZINCRBY when the key already exists to
    # avoid double-counting.
    for period in ("day", "week"):
        key, ttl = _key_ttl(period, now)
        if await redis.exists(key):
            pipe = redis.pipeline()
            pipe.zincrby(key, 1, k)
            pipe.expire(key, ttl)
            pipe.hset(DISPLAY_KEY, k, city)
            await pipe.execute()
        else:
            await rebuild(session, redis, period, now)


async def top_cities(session, redis, period: str, limit: int, now: dt.datetime | None = None) -> list[dict]:
    key = await ensure_built(session, redis, period, now)
    rows = await redis.zrevrange(key, 0, limit - 1, withscores=True)
    if not rows:
        return []
    members = [m for m, _ in rows]
    names = await redis.hmget(DISPLAY_KEY, members)
    return [
        {"key": m, "name": name or m.title(), "count": int(score), "rank": i + 1}
        for i, ((m, score), name) in enumerate(zip(rows, names))
    ]


async def city_rank(session, redis, period: str, city: str, now: dt.datetime | None = None) -> dict | None:
    k = normalize_city(city)
    if not k:
        return None
    key = await ensure_built(session, redis, period, now)
    rank = await redis.zrevrank(key, k)
    if rank is None:
        return None
    score = await redis.zscore(key, k)
    name = await redis.hget(DISPLAY_KEY, k)
    return {"key": k, "name": name or k.title(), "count": int(score), "rank": rank + 1}
```

> Note: this task makes `/pintes` posts implicitly exercise `bump` only after Task 4 wires it. Tasks 2's tests build rankings via `top_cities`/`rebuild` directly, which works regardless of Task 4.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_rankings.py -v`
Expected: PASS (all tasks-1 and task-2 tests).

- [ ] **Step 5: Verify** — full `pytest tests/test_rankings.py -v` green.

---

### Task 3: `GET /rankings` endpoint

**Files:**
- Create: `back/app/routers/rankings.py`
- Modify: `back/app/main.py` (register router)
- Test: `back/tests/test_rankings.py` (append)

**Interfaces:**
- Consumes (Task 2): `rankings.top_cities`, `rankings.city_rank`.
- Consumes (existing): `app.deps.get_current_account`, `app.db.get_session`, `app.redis_client.get_redis`.
- Produces: `GET /rankings?period=day|week&limit=10` → `{period, cities:[{key,name,count,rank}], me:{...}|null}`.

- [ ] **Step 1: Write the failing test**

```python
# back/tests/test_rankings.py (append)
@pytest.mark.asyncio
async def test_rankings_endpoint_shape_and_me(client):
    lyon = await _account(client, "L1", "Lyon")
    paris = await _account(client, "P1", "Paris")
    await _post(client, lyon, b"a")
    await _post(client, lyon, b"b")
    await _post(client, paris, b"c")

    r = await client.get("/rankings?period=day&limit=10", headers=lyon)
    assert r.status_code == 200
    body = r.json()
    assert body["period"] == "day"
    assert [c["name"] for c in body["cities"]][:2] == ["Lyon", "Paris"]
    assert body["cities"][0]["rank"] == 1
    assert body["me"]["name"] == "Lyon" and body["me"]["rank"] == 1


@pytest.mark.asyncio
async def test_rankings_me_null_when_city_silent(client):
    lyon = await _account(client, "L1", "Lyon")
    nantes = await _account(client, "N1", "Nantes")
    await _post(client, lyon, b"a")
    r = await client.get("/rankings?period=day", headers=nantes)
    assert r.json()["me"] is None


@pytest.mark.asyncio
async def test_rankings_rejects_bad_period(client, auth_headers):
    r = await client.get("/rankings?period=month", headers=auth_headers)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_rankings_requires_auth(client):
    r = await client.get("/rankings")
    assert r.status_code == 401
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_rankings.py -k rankings_endpoint -v`
Expected: FAIL — 404 (route not registered).

- [ ] **Step 3: Write minimal implementation**

```python
# back/app/routers/rankings.py
from fastapi import APIRouter, Depends, Query

from app.db import get_session
from app.deps import get_current_account
from app.domain import rankings
from app.redis_client import get_redis

router = APIRouter()


@router.get("/rankings")
async def get_rankings(
    period: str = Query("day", pattern="^(day|week)$"),
    limit: int = Query(10, ge=1, le=50),
    account=Depends(get_current_account),
    session=Depends(get_session),
    redis=Depends(get_redis),
):
    cities = await rankings.top_cities(session, redis, period, limit)
    me = await rankings.city_rank(session, redis, period, account.city)
    return {"period": period, "cities": cities, "me": me}
```

Modify `back/app/main.py` — add to imports and registration:

```python
from app.routers import auth, counter, feed, pintes, profile, rankings
# ...
    app.include_router(profile.router)
    app.include_router(rankings.router)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_rankings.py -v`
Expected: PASS (all rankings tests).

- [ ] **Step 5: Verify** — `pytest tests/test_rankings.py -v` green.

---

### Task 4: Bump rankings + publish `rankings_changed` on pinte post

**Files:**
- Modify: `back/app/routers/pintes.py`
- Test: `back/tests/test_rankings.py` (append)

**Interfaces:**
- Consumes (Task 2): `rankings.bump`.
- Produces: side effect — each successful `POST /pintes` increments day+week ZSETs and publishes `{"type":"rankings_changed"}` on the `feed` channel.

- [ ] **Step 1: Write the failing test**

```python
# back/tests/test_rankings.py (append)
@pytest.mark.asyncio
async def test_post_pinte_updates_rankings_live(client, redis, session):
    lyon = await _account(client, "L1", "Lyon")
    # Warm the day ZSET so bump uses ZINCRBY (key exists).
    from app.domain import rankings as r
    await r.ensure_built(session, redis, "day")
    await _post(client, lyon, b"a")
    top = await r.top_cities(session, redis, "day", 10)
    assert top[0]["key"] == "lyon" and top[0]["count"] == 1


@pytest.mark.asyncio
async def test_post_pinte_publishes_rankings_changed(client, redis):
    lyon = await _account(client, "L1", "Lyon")
    pubsub = redis.pubsub()
    await pubsub.subscribe("feed")
    await _post(client, lyon, b"a")
    seen = set()
    for _ in range(6):
        msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=2)
        if msg:
            import json
            seen.add(json.loads(msg["data"]).get("type"))
    await pubsub.unsubscribe("feed")
    assert "rankings_changed" in seen
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_rankings.py -k "live or rankings_changed" -v`
Expected: FAIL — `test_post_pinte_publishes_rankings_changed` (no such message published). The `live` test may already pass via rebuild, but the publish test fails.

- [ ] **Step 3: Write minimal implementation**

In `back/app/routers/pintes.py`, add the import and the two calls after `total = await incr_total(redis)` (before `return`):

```python
from app.domain.counter import incr_total
from app.domain.rankings import bump as bump_rankings
# ...
    total = await incr_total(redis)
    await bump_rankings(session, redis, account.city)
    # ... existing item dict + feed_item/counter publishes ...
    await redis.publish("feed", json.dumps({"type": "rankings_changed"}))
    return {"number": pinte.number, "total": total, "item": item}
```

(Keep the existing `feed_item` and `counter` publishes; add the `rankings_changed` publish alongside them.)

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_rankings.py -v`
Expected: PASS (all). Also run `pytest -q` to confirm no regression in other suites.

- [ ] **Step 5: Verify** — `pytest tests/test_rankings.py -v` and `pytest -q` green.

---

### Task 5: Flutter ranking model + `ApiClient.getRankings`

**Files:**
- Create: `app/lib/models/ranking.dart`
- Modify: `app/lib/data/api_client.dart`
- Test: `app/test/rankings_test.dart`

**Interfaces:**
- Produces: `CityRank{key,name,count,rank}`, `Rankings{period, cities:List<CityRank>, me:CityRank?}`, both with `fromJson`; `ApiClient.getRankings({String period='day', int limit=10}) -> Future<Rankings>`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/rankings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/ranking.dart';

void main() {
  test('Rankings.fromJson parses cities and nullable me', () {
    final j = {
      'period': 'day',
      'cities': [
        {'key': 'lyon', 'name': 'Lyon', 'count': 5, 'rank': 1},
        {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
      ],
      'me': {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
    };
    final r = Rankings.fromJson(j);
    expect(r.period, 'day');
    expect(r.cities.first.name, 'Lyon');
    expect(r.me!.rank, 2);

    final r2 = Rankings.fromJson({'period': 'week', 'cities': [], 'me': null});
    expect(r2.me, isNull);
    expect(r2.cities, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/rankings_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:pintes_app/models/ranking.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/models/ranking.dart
class CityRank {
  const CityRank({
    required this.key,
    required this.name,
    required this.count,
    required this.rank,
  });
  final String key;
  final String name;
  final int count;
  final int rank;

  factory CityRank.fromJson(Map<String, dynamic> j) => CityRank(
    key: j['key'] as String,
    name: j['name'] as String,
    count: j['count'] as int,
    rank: j['rank'] as int,
  );
}

class Rankings {
  const Rankings({required this.period, required this.cities, this.me});
  final String period;
  final List<CityRank> cities;
  final CityRank? me;

  factory Rankings.fromJson(Map<String, dynamic> j) => Rankings(
    period: j['period'] as String,
    cities: (j['cities'] as List)
        .map((e) => CityRank.fromJson(e as Map<String, dynamic>))
        .toList(),
    me: j['me'] == null
        ? null
        : CityRank.fromJson(j['me'] as Map<String, dynamic>),
  );
}
```

In `app/lib/data/api_client.dart`, add the import and method:

```dart
import '../models/ranking.dart';
// ...
  Future<Rankings> getRankings({String period = 'day', int limit = 10}) async {
    final r = await _client.get(
      _uri('/rankings', {'period': period, 'limit': limit}),
      headers: await _headers(),
    );
    if (r.statusCode != 200) _fail(r);
    return Rankings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/rankings_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify** — `flutter analyze lib/models/ranking.dart lib/data/api_client.dart` clean; test green.

---

### Task 6: `RankingsController` + SSE wiring

**Files:**
- Create: `app/lib/state/rankings_controller.dart`
- Modify: `app/lib/state/counter_controller.dart` (handle `rankings_changed`)
- Test: `app/test/rankings_test.dart` (append)

**Interfaces:**
- Consumes (Task 5): `Rankings`, `CityRank`, `apiClientProvider.getRankings`.
- Produces:
  - `RankingsUiState{String period; AsyncValue<Rankings> data}` with `copyWith`.
  - `rankingsControllerProvider` (`NotifierProvider<RankingsController, RankingsUiState>`) with `setPeriod(String)`, `refresh()`, `onRemoteChange()`.
  - `myWeekCityRankProvider` (`FutureProvider<CityRank?>`).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/rankings_test.dart (append these imports at top of file)
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/rankings_controller.dart';

// ... inside main(), add:
  ProviderContainer container(MockClient mock) => ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(mock),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );

  http.Response ok(String period, List<String> names) => http.Response(
        jsonEncode({
          'period': period,
          'cities': [
            for (var i = 0; i < names.length; i++)
              {'key': names[i].toLowerCase(), 'name': names[i],
               'count': 10 - i, 'rank': i + 1},
          ],
          'me': null,
        }),
        200,
      );

  testWidgets('controller loads day then switches to week', (tester) async {
    var lastPeriod = '';
    final c = container(MockClient((req) async {
      lastPeriod = req.url.queryParameters['period']!;
      return ok(lastPeriod, ['Lyon', 'Paris']);
    }));
    addTearDown(c.dispose);

    // Force build + initial refresh.
    c.read(rankingsControllerProvider);
    await tester.pumpAndSettle();
    expect(c.read(rankingsControllerProvider).data.value!.cities.first.name, 'Lyon');

    c.read(rankingsControllerProvider.notifier).setPeriod('week');
    await tester.pumpAndSettle();
    expect(c.read(rankingsControllerProvider).period, 'week');
    expect(lastPeriod, 'week');
  });

  testWidgets('onRemoteChange debounces to a single refresh', (tester) async {
    var calls = 0;
    final c = container(MockClient((req) async {
      calls++;
      return ok('day', ['Lyon']);
    }));
    addTearDown(c.dispose);
    c.read(rankingsControllerProvider);
    await tester.pumpAndSettle();
    final baseline = calls; // 1 (initial)

    final n = c.read(rankingsControllerProvider.notifier);
    n.onRemoteChange();
    n.onRemoteChange();
    n.onRemoteChange();
    await tester.pump(const Duration(milliseconds: 700));
    expect(calls, baseline + 1); // coalesced
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/rankings_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../rankings_controller.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/state/rankings_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import 'providers.dart';

class RankingsUiState {
  const RankingsUiState({required this.period, required this.data});
  final String period;
  final AsyncValue<Rankings> data;
  RankingsUiState copyWith({String? period, AsyncValue<Rankings>? data}) =>
      RankingsUiState(period: period ?? this.period, data: data ?? this.data);
}

class RankingsController extends Notifier<RankingsUiState> {
  Timer? _debounce;

  @override
  RankingsUiState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const RankingsUiState(period: 'day', data: AsyncLoading());
  }

  void setPeriod(String p) {
    if (p == state.period) return;
    state = state.copyWith(period: p, data: const AsyncLoading());
    refresh();
  }

  Future<void> refresh() async {
    final period = state.period;
    try {
      final r = await ref.read(apiClientProvider).getRankings(period: period);
      if (!ref.mounted || period != state.period) return;
      state = state.copyWith(data: AsyncData(r));
    } catch (e, st) {
      if (!ref.mounted || period != state.period) return;
      state = state.copyWith(data: AsyncError(e, st));
    }
  }

  /// Signalé par le flux SSE quand une pinte modifie le classement.
  void onRemoteChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (ref.mounted) refresh();
    });
  }
}

final rankingsControllerProvider =
    NotifierProvider<RankingsController, RankingsUiState>(RankingsController.new);

/// Rang de la ville de l'utilisateur sur la semaine (pour le profil), indépendant
/// de la période affichée sur l'écran Villes.
final myWeekCityRankProvider = FutureProvider<CityRank?>((ref) async {
  final r = await ref.watch(apiClientProvider).getRankings(period: 'week', limit: 1);
  return r.me;
});
```

In `app/lib/state/counter_controller.dart`, add a case in the `switch (j['type'])` inside `_listen`:

```dart
              case 'rankings_changed':
                ref.read(rankingsControllerProvider.notifier).onRemoteChange();
```

Add the import at the top of `counter_controller.dart`:

```dart
import 'rankings_controller.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/rankings_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify** — `flutter analyze lib/state/rankings_controller.dart lib/state/counter_controller.dart` clean; tests green.

---

### Task 7: `RankingsScreen` (Villes) widget

**Files:**
- Create: `app/lib/ui/rankings_screen.dart`
- Test: `app/test/rankings_test.dart` (append)

**Interfaces:**
- Consumes (Task 6): `rankingsControllerProvider`, `RankingsUiState`; (Task 5) `Rankings`, `CityRank`.
- Consumes (existing): `AppTokens`, `displayStyle` (`theme/app_theme.dart`), `formatCountFr` (`util/format.dart`).
- Produces: `class RankingsScreen extends ConsumerWidget`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/rankings_test.dart (append)
// (reuse container() + ok() helpers from Task 6; add import:)
import 'package:pintes_app/app.dart';
import 'package:pintes_app/ui/rankings_screen.dart';

  testWidgets('rankings screen renders rows and highlights ta ville',
      (tester) async {
    final c = container(MockClient((req) async => http.Response(
          jsonEncode({
            'period': 'day',
            'cities': [
              {'key': 'lyon', 'name': 'Lyon', 'count': 120, 'rank': 1},
              {'key': 'paris', 'name': 'Paris', 'count': 90, 'rank': 2},
            ],
            'me': {'key': 'paris', 'name': 'Paris', 'count': 90, 'rank': 2},
          }),
          200,
        )));
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const PintesApp(home: RankingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lyon'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('ta ville'), findsOneWidget); // pill sur la ville de me
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/rankings_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../rankings_screen.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/ui/rankings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import '../state/rankings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/format.dart';

const _medal2 = Color(0xFFFF8A3D);

class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rankingsControllerProvider);
    final notifier = ref.read(rankingsControllerProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('La guerre\ndes villes',
                style: displayStyle(size: 30).copyWith(height: 1.05)),
            const SizedBox(height: 16),
            Row(
              children: [
                _PeriodPill(
                  label: 'Aujourd\'hui',
                  active: s.period == 'day',
                  onTap: () => notifier.setPeriod('day'),
                ),
                const SizedBox(width: 8),
                _PeriodPill(
                  label: 'Cette semaine',
                  active: s.period == 'week',
                  onTap: () => notifier.setPeriod('week'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            s.data.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorBox(onRetry: notifier.refresh),
              data: (r) => r.cities.isEmpty
                  ? const _EmptyBox()
                  : _List(rankings: r),
            ),
            const SizedBox(height: 24),
            const _DerbyTeaser(),
          ],
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTokens.ink : AppTokens.foam,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: active ? Colors.white : AppTokens.muted,
              )),
        ),
      );
}

class _List extends StatelessWidget {
  const _List({required this.rankings});
  final Rankings rankings;
  @override
  Widget build(BuildContext context) {
    final top = rankings.cities.first.count;
    return Column(
      children: [
        for (final c in rankings.cities) ...[
          _Row(city: c, topCount: top, isMine: c.key == rankings.me?.key),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.city, required this.topCount, required this.isMine});
  final CityRank city;
  final int topCount;
  final bool isMine;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Color get _fill => switch (city.rank) {
        1 => AppTokens.amber,
        2 => _medal2,
        3 => AppTokens.coral,
        _ => AppTokens.sky,
      };

  @override
  Widget build(BuildContext context) {
    final isTop3 = city.rank <= 3;
    final label = _medals[city.rank] ?? '${city.rank} ·';
    final headStyle = TextStyle(
      fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w600,
      fontSize: isTop3 ? 17 : 16,
      color: isTop3 ? AppTokens.ink : const Color(0xFF6A573C),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text('$label ${city.name}', style: headStyle),
                  if (isMine)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.coral,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text('ta ville',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Text(formatCountFr(city.count), style: headStyle),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: topCount == 0 ? 0 : (city.count / topCount).clamp(0.0, 1.0),
            minHeight: isTop3 ? 16 : 14,
            backgroundColor: AppTokens.rail,
            color: _fill,
          ),
        ),
      ],
    );
  }
}

class _DerbyTeaser extends StatelessWidget {
  const _DerbyTeaser();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF241308),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚔️ Derby du week-end',
                style: displayStyle(size: 18).copyWith(color: const Color(0xFFFFCB6B))),
            const SizedBox(height: 4),
            const Text('Bientôt : des duels programmés entre villes.',
                style: TextStyle(color: Color(0xFFFFE3C2), fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text("Personne n'a encore trinqué. Sois le premier ! 🍺",
            textAlign: TextAlign.center, style: TextStyle(color: AppTokens.muted, fontWeight: FontWeight.w600)),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Text('Classement indisponible.', style: TextStyle(color: AppTokens.muted)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/rankings_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify** — `flutter analyze lib/ui/rankings_screen.dart` clean; tests green.

---

### Task 8: Wire the "Villes" tab + profile "rang ville"

**Files:**
- Modify: `app/lib/ui/app_shell.dart`
- Modify: `app/lib/ui/profile_screen.dart`
- Test: `app/test/rankings_test.dart` (append)

**Interfaces:**
- Consumes (Task 7): `RankingsScreen`; (Task 6) `myWeekCityRankProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/rankings_test.dart (append) — needs: import 'package:pintes_app/ui/app_shell.dart';
  testWidgets('Villes tab opens the rankings screen', (tester) async {
    final c = container(MockClient((req) async {
      if (req.url.path == '/rankings') return ok('day', ['Lyon']);
      if (req.url.path == '/me') {
        return http.Response(
            jsonEncode({'pseudo': 'Toi', 'city': 'Lyon', 'myCount': 0, 'streak': 0}), 200);
      }
      if (req.url.path == '/counter') return http.Response('{"total":0}', 200);
      return http.Response('{}', 200);
    }));
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const PintesApp(home: AppShell()),
    ));
    await tester.pump();
    await tester.tap(find.text('Villes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('La guerre'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/rankings_test.dart -k Villes`
Expected: FAIL — tapping "Villes" does nothing (tab is inert), `La guerre` not found.

- [ ] **Step 3: Write minimal implementation**

In `app/lib/ui/app_shell.dart`: import the screen, add it to the `IndexedStack`, and route the tab. The stack becomes `[Home, Feed, Rankings, Profile]` (indices 0–3); the bottom bar slots stay `Accueil(0) Fil(1) FAB(2) Villes(3) Profil(4)`.

```dart
import 'rankings_screen.dart';
// ...
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onAddPinte: _openCapture),
          const FeedScreen(),
          const RankingsScreen(),
          const ProfileScreen(),
        ],
      ),
// ...
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: switch (_index) { 0 => 0, 1 => 1, 2 => 3, _ => 4 },
        onTap: (i) {
          if (i == 2) return; // slot central FAB
          setState(() => _index = switch (i) {
            0 => 0,
            1 => 1,
            3 => 2, // Villes -> RankingsScreen
            _ => 3, // Profil
          });
        },
        // ... unchanged type/colors/items ...
```

> The `items` list (5 entries incl. the empty FAB slot) is unchanged.

In `app/lib/ui/profile_screen.dart`: replace the static `const _Stat('—', 'rang ville')` with a watch on `myWeekCityRankProvider`. Add `import '../state/rankings_controller.dart';`. Inside `build` (it's already a `ConsumerWidget` with `ref`):

```dart
              Consumer(
                builder: (context, ref, _) {
                  final me = ref.watch(myWeekCityRankProvider);
                  final label = me.maybeWhen(
                    data: (c) => c == null ? '—' : '${c.rank}ᵉ',
                    orElse: () => '—',
                  );
                  return _Stat(label, 'rang ville');
                },
              ),
```

(Replace the third `_Stat` in the `Row`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/rankings_test.dart`
Expected: PASS (all rankings tests).

- [ ] **Step 5: Verify** — run full suites:
  - `flutter analyze` → No issues found.
  - `flutter test` → all green.
  - Visual: generate a 392×846 screenshot of `RankingsScreen` (as done for splash/login) and confirm fidelity to the mockup (podium colors amber/`#FF8A3D`/coral/sky, "ta ville" pill, Derby card).

---

## Self-Review

**Spec coverage:** §4.1 → Tasks 1–2; §4.2 → Task 3; §4.3 → Task 4; §4.4 → Task 3; §5 (SSE) → Task 6; §6.1 → Task 5; §6.2 → Task 5; §6.3 → Task 6; §6.4 → Task 6; §6.5 (screen) → Task 7; §6.6 (tab) → Task 8; §6.7 (profile) → Task 8; §8.1 → Tasks 1–4 tests; §8.2 → Tasks 5–8 tests; §8.3 → Task 8 Step 5. Acceptance criteria 1–5 all covered.

**Placeholder scan:** No TBD/TODO; every code step shows full code; no "handle errors appropriately".

**Type consistency:** `CityRank{key,name,count,rank}` and `Rankings{period,cities,me}` used identically across Tasks 5–8. Backend dict shape `{key,name,count,rank}` consistent across `top_cities`/`city_rank`/endpoint/tests. `bump(session, redis, city)`, `top_cities(session, redis, period, limit)`, `city_rank(session, redis, period, city)` signatures consistent between Tasks 2, 3, 4. `rankingsControllerProvider` / `myWeekCityRankProvider` names consistent Tasks 6–8.
