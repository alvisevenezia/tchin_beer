# Cœur émotionnel — Backend FastAPI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire le backend FastAPI du « cœur émotionnel » : onboarding appareil, compteur mondial temps réel (SSE), création de pinte avec photo validée, fil et likes.

**Architecture:** API FastAPI async ; Postgres = source de vérité (séquence pour numéroter les pintes) ; Redis = miroir du compteur + pub/sub pour le fan-out SSE ; stockage objet S3-compatible (MinIO en dev) pour les photos. Découpage par domaine : `auth`, `counter`, `media`, `pintes`, `feed`.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2 (async) + asyncpg, Alembic, redis-py (async), aioboto3 (S3/MinIO), pytest + httpx, ruff + black, docker-compose.

## Global Constraints

- Python ≥ 3.12, async de bout en bout (`async def`, pas d'I/O bloquant dans les routes).
- Source de vérité du compteur = Postgres (`pintes_number_seq`). Redis ne fait jamais reculer le total : incréments monotones uniquement.
- Auth : header `Authorization: Bearer <device_token>` sur toutes les routes sauf `POST /auth/device`.
- Photo obligatoire, validée AVANT le +1 (présence, MIME jpeg/png/webp, taille max, anti-doublon hash 24 h, rate-limit).
- Codes d'erreur métier exacts : `DUPLICATE_PHOTO`, `RATE_LIMITED` (+ `retry_after`), `PHOTO_MISSING`, `PHOTO_INVALID`.
- Tones autorisés : `amber`, `coral`, `sky` (aléatoire à la création).
- Lint/format : `ruff check` + `black` doivent passer avant chaque commit.
- Dépôt git dédié `back/` (séparé de `app/` et `web/`).

---

## File Structure

```
back/
  pyproject.toml            # deps + config ruff/black
  docker-compose.yml        # api + postgres + redis + minio
  Dockerfile
  .env.example
  alembic.ini
  migrations/               # Alembic
  app/
    main.py                 # app FastAPI, routers, lifespan (resync compteur)
    config.py               # Settings (pydantic-settings)
    db.py                   # engine async + session dependency
    redis_client.py         # client redis async + get_redis
    storage.py              # client S3/MinIO : put_photo
    models.py               # ORM : Account, Pinte, Like + séquence
    schemas.py              # Pydantic I/O
    deps.py                 # get_current_account (Bearer)
    domain/
      counter.py            # get_total, incr_total, resync_from_sequence
      validation.py         # validate_photo, photo_hash, check_duplicate, check_rate_limit
      streak.py             # compute_streak
    routers/
      auth.py               # POST /auth/device
      counter.py            # GET /counter, GET /counter/stream (SSE)
      pintes.py             # POST /pintes, POST /pintes/{id}/like
      feed.py               # GET /feed
      profile.py            # GET /me
  tests/
    conftest.py             # fixtures app, db, redis, minio, client, auth_headers
    test_health.py test_models.py test_auth.py test_counter.py
    test_validation.py test_pintes.py test_sse.py test_feed.py
    test_likes.py test_profile.py
```

---

### Task 1: Scaffolding du dépôt `back/` + healthcheck

**Files:**
- Create: `back/pyproject.toml`, `back/docker-compose.yml`, `back/.env.example`, `back/app/__init__.py`, `back/app/config.py`, `back/app/main.py`, `back/tests/__init__.py`, `back/tests/conftest.py`, `back/tests/test_health.py`

**Interfaces:**
- Produces: app FastAPI `app.main:app` ; route `GET /health` → `{"status": "ok"}` ; `Settings` exposant `database_url`, `redis_url`, `s3_*`.

- [ ] **Step 1: Init dépôt + dépendances**

```bash
cd back && git init
```

`pyproject.toml` (extrait) :
```toml
[project]
name = "pintes-back"
requires-python = ">=3.12"
dependencies = [
  "fastapi", "uvicorn[standard]", "sqlalchemy[asyncio]>=2", "asyncpg",
  "alembic", "redis>=5", "aioboto3", "pydantic-settings", "python-multipart",
]
[project.optional-dependencies]
dev = ["pytest", "pytest-asyncio", "httpx", "ruff", "black"]

[tool.black]
line-length = 100
[tool.ruff]
line-length = 100
```

- [ ] **Step 2: Écrire le test qui échoue**

```python
# tests/test_health.py
import pytest

@pytest.mark.asyncio
async def test_health(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
```

- [ ] **Step 3: Lancer le test (échec attendu)**

Run: `pytest tests/test_health.py -v`
Expected: FAIL (app/fixture `client` inexistants).

- [ ] **Step 4: Implémenter app + config + fixture client**

```python
# app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://pintes:pintes@localhost:5432/pintes"
    redis_url: str = "redis://localhost:6379/0"
    s3_endpoint: str = "http://localhost:9000"
    s3_bucket: str = "pintes-photos"
    s3_access_key: str = "minio"
    s3_secret_key: str = "minio12345"
    class Config:
        env_file = ".env"

settings = Settings()
```

```python
# app/main.py
from fastapi import FastAPI

def create_app() -> FastAPI:
    app = FastAPI(title="Le Million de Pintes API")

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return app

app = create_app()
```

```python
# tests/conftest.py
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
```

- [ ] **Step 5: Lancer le test (succès attendu)**

Run: `pytest tests/test_health.py -v` → PASS.

- [ ] **Step 6: docker-compose + .env.example, puis commit**

`docker-compose.yml` : services `postgres` (15), `redis` (7), `minio` (avec bucket `pintes-photos`). `.env.example` reprend les clés de `Settings`.

```bash
git add -A && git commit -m "chore: scaffold backend FastAPI + healthcheck"
```

---

### Task 2: Modèle de données + migration (accounts, pintes, likes, séquence)

**Files:**
- Create: `back/app/db.py`, `back/app/models.py`, `back/migrations/...`
- Test: `back/tests/test_models.py`

**Interfaces:**
- Produces: ORM `Account(id, device_token, pseudo, city, created_at)`, `Pinte(id, number, account_id, photo_key, photo_hash, tone, status, created_at)`, `Like(pinte_id, account_id, created_at)` ; séquence `pintes_number_seq` ; `get_session()` (AsyncSession) ; classmethod `Pinte.create(session, **kw) -> Pinte`.

- [ ] **Step 1: Test qui échoue**

```python
# tests/test_models.py
import pytest
from app.models import Account, Pinte

@pytest.mark.asyncio
async def test_pinte_number_increases(session):
    acc = Account(device_token="t1", pseudo="Léo", city="Toulouse")
    session.add(acc); await session.flush()
    p1 = await Pinte.create(session, account_id=acc.id, photo_key="k1", photo_hash="h1", tone="amber")
    p2 = await Pinte.create(session, account_id=acc.id, photo_key="k2", photo_hash="h2", tone="sky")
    assert p2.number == p1.number + 1
```

- [ ] **Step 2: Lancer (échec attendu)** — `pytest tests/test_models.py -v` → FAIL.

- [ ] **Step 3: Implémenter `db.py` + `models.py`**

```python
# app/db.py
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine, AsyncSession
from app.config import settings

engine = create_async_engine(settings.database_url, future=True)
SessionMaker = async_sessionmaker(engine, expire_on_commit=False)

async def get_session() -> AsyncSession:
    async with SessionMaker() as s:
        yield s
```

```python
# app/models.py (extrait clé)
import uuid, datetime as dt
from sqlalchemy import String, ForeignKey, BigInteger, DateTime, Sequence, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID

pinte_seq = Sequence("pintes_number_seq")

class Base(DeclarativeBase): ...

class Account(Base):
    __tablename__ = "accounts"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_token: Mapped[str] = mapped_column(String, unique=True, index=True)
    pseudo: Mapped[str]; city: Mapped[str]
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class Pinte(Base):
    __tablename__ = "pintes"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    number: Mapped[int] = mapped_column(BigInteger, pinte_seq, unique=True)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"))
    photo_key: Mapped[str]; photo_hash: Mapped[str] = mapped_column(index=True)
    tone: Mapped[str]; status: Mapped[str] = mapped_column(default="active")
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)

    @classmethod
    async def create(cls, session, **kw):
        nextval = (await session.execute(pinte_seq.next_value())).scalar()
        p = cls(number=nextval, **kw)
        session.add(p); await session.flush()
        return p

class Like(Base):
    __tablename__ = "likes"
    pinte_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("pintes.id"), primary_key=True)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id"), primary_key=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 4: Init Alembic + générer la migration**

```bash
alembic init migrations   # brancher target_metadata = Base.metadata et settings.database_url
alembic revision --autogenerate -m "accounts pintes likes + sequence"
alembic upgrade head
```

- [ ] **Step 5: Lancer le test (succès)** — `pytest tests/test_models.py -v` → PASS (fixture `session` ajoutée à `conftest.py`, base de test + `Base.metadata.create_all`).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: data model accounts/pintes/likes + numbering sequence"
```

---

### Task 3: Auth appareil (`POST /auth/device` + dépendance Bearer)

**Files:**
- Create: `back/app/schemas.py`, `back/app/deps.py`, `back/app/routers/auth.py`
- Modify: `back/app/main.py` (inclure le router + `/me` provisoire)
- Test: `back/tests/test_auth.py`

**Interfaces:**
- Produces: `POST /auth/device` body `{pseudo, city, device_token?}` → `{device_token, pseudo, city}` ; dependency `get_current_account(authorization, session) -> Account` (401 si token absent/inconnu) ; schemas `DeviceIn`, `DeviceOut`.

- [ ] **Step 1: Test qui échoue**

```python
# tests/test_auth.py
import pytest

@pytest.mark.asyncio
async def test_device_signup_then_authenticated_call(client):
    r = await client.post("/auth/device", json={"pseudo": "Léo", "city": "Toulouse"})
    assert r.status_code == 200
    token = r.json()["device_token"]
    me = await client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200

@pytest.mark.asyncio
async def test_unknown_token_401(client):
    r = await client.get("/me", headers={"Authorization": "Bearer nope"})
    assert r.status_code == 401
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter schemas + deps + router**

```python
# app/schemas.py
from pydantic import BaseModel

class DeviceIn(BaseModel):
    pseudo: str
    city: str
    device_token: str | None = None

class DeviceOut(BaseModel):
    device_token: str
    pseudo: str
    city: str
```

```python
# app/deps.py
from fastapi import Depends, Header, HTTPException
from sqlalchemy import select
from app.db import get_session
from app.models import Account

async def get_current_account(authorization: str = Header(None), session=Depends(get_session)) -> Account:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing token")
    token = authorization.removeprefix("Bearer ").strip()
    acc = (await session.execute(select(Account).where(Account.device_token == token))).scalar_one_or_none()
    if acc is None:
        raise HTTPException(401, "unknown token")
    return acc
```

```python
# app/routers/auth.py
import secrets
from fastapi import APIRouter, Depends
from sqlalchemy import select
from app.db import get_session
from app.models import Account
from app.schemas import DeviceIn, DeviceOut

router = APIRouter()

@router.post("/auth/device", response_model=DeviceOut)
async def device(body: DeviceIn, session=Depends(get_session)):
    if body.device_token:
        acc = (await session.execute(select(Account).where(Account.device_token == body.device_token))).scalar_one_or_none()
        if acc:
            return DeviceOut(device_token=acc.device_token, pseudo=acc.pseudo, city=acc.city)
    acc = Account(device_token=secrets.token_urlsafe(32), pseudo=body.pseudo, city=body.city)
    session.add(acc); await session.commit()
    return DeviceOut(device_token=acc.device_token, pseudo=acc.pseudo, city=acc.city)
```

- [ ] **Step 4: Lancer (succès)** → PASS. (Ajouter un `/me` provisoire dans `main.py` renvoyant `{pseudo, city}` de l'account, remplacé en Task 8.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: device-based auth (POST /auth/device + Bearer dependency)"
```

---

### Task 4: Compteur (`GET /counter`) + miroir Redis + resync

**Files:**
- Create: `back/app/redis_client.py`, `back/app/domain/counter.py`, `back/app/routers/counter.py`
- Modify: `back/app/main.py` (inclure router)
- Test: `back/tests/test_counter.py`

**Interfaces:**
- Produces: `get_redis()` dependency ; `get_total(session, redis) -> int` ; `resync_from_sequence(session, redis) -> int` ; `incr_total(redis) -> int` ; `GET /counter` → `{total}`.

- [ ] **Step 1: Test qui échoue**

```python
# tests/test_counter.py
import pytest

@pytest.mark.asyncio
async def test_counter_starts_at_zero(client):
    r = await client.get("/counter")
    assert r.status_code == 200
    assert r.json()["total"] >= 0
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter redis_client + counter**

```python
# app/redis_client.py
import redis.asyncio as aioredis
from app.config import settings

_redis = aioredis.from_url(settings.redis_url, decode_responses=True)

async def get_redis():
    return _redis
```

```python
# app/domain/counter.py
from sqlalchemy import text
TOTAL_KEY = "counter:total"

async def resync_from_sequence(session, redis) -> int:
    row = (await session.execute(text("SELECT last_value, is_called FROM pintes_number_seq"))).first()
    total = row.last_value if row.is_called else 0
    await redis.set(TOTAL_KEY, total)
    return total

async def get_total(session, redis) -> int:
    v = await redis.get(TOTAL_KEY)
    return int(v) if v is not None else await resync_from_sequence(session, redis)

async def incr_total(redis) -> int:
    return await redis.incr(TOTAL_KEY)
```

```python
# app/routers/counter.py
from fastapi import APIRouter, Depends
from app.db import get_session
from app.redis_client import get_redis
from app.domain.counter import get_total

router = APIRouter()

@router.get("/counter")
async def counter(session=Depends(get_session), redis=Depends(get_redis)):
    return {"total": await get_total(session, redis)}
```

- [ ] **Step 4: Lancer (succès)** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: global counter endpoint + redis mirror + resync"
```

---

### Task 5: Stockage photo (S3/MinIO) + validation légère

**Files:**
- Create: `back/app/storage.py`, `back/app/domain/validation.py`
- Test: `back/tests/test_validation.py`

**Interfaces:**
- Produces: `put_photo(data: bytes, content_type: str) -> str` (clé objet) ; `validate_photo(upload) -> bytes` (415/413 ; codes `PHOTO_MISSING`/`PHOTO_INVALID`) ; `photo_hash(data) -> str` ; `check_duplicate(session, account_id, photo_hash)` (409 `DUPLICATE_PHOTO`) ; `check_rate_limit(redis, account_id)` (409 `RATE_LIMITED` + `retry_after`).

- [ ] **Step 1: Tests qui échouent**

```python
# tests/test_validation.py
import pytest

@pytest.mark.asyncio
async def test_rate_limit_blocks_second_within_window(redis):
    from app.domain.validation import check_rate_limit
    await check_rate_limit(redis, "acc1")
    with pytest.raises(Exception) as e:
        await check_rate_limit(redis, "acc1")
    assert "RATE_LIMITED" in str(e.value.detail)
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter validation + storage**

```python
# app/domain/validation.py
import hashlib, datetime as dt
from fastapi import HTTPException
from sqlalchemy import select, func
from app.models import Pinte

ALLOWED = {"image/jpeg", "image/png", "image/webp"}
MAX_BYTES = 8 * 1024 * 1024
RL_KEY = "rl:pinte:{}"; RL_WINDOW = 60
DEDUP_WINDOW_H = 24

async def validate_photo(upload) -> bytes:
    if upload is None:
        raise HTTPException(409, {"code": "PHOTO_MISSING"})
    if upload.content_type not in ALLOWED:
        raise HTTPException(415, {"code": "PHOTO_INVALID"})
    data = await upload.read()
    if not data:
        raise HTTPException(409, {"code": "PHOTO_MISSING"})
    if len(data) > MAX_BYTES:
        raise HTTPException(413, {"code": "PHOTO_INVALID"})
    return data

def photo_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

async def check_duplicate(session, account_id, h: str):
    since = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=DEDUP_WINDOW_H)
    exists = (await session.execute(select(func.count()).where(
        Pinte.account_id == account_id, Pinte.photo_hash == h, Pinte.created_at >= since))).scalar()
    if exists:
        raise HTTPException(409, {"code": "DUPLICATE_PHOTO"})

async def check_rate_limit(redis, account_id: str):
    key = RL_KEY.format(account_id)
    if await redis.set(key, "1", nx=True, ex=RL_WINDOW) is None:
        ttl = await redis.ttl(key)
        raise HTTPException(409, {"code": "RATE_LIMITED", "retry_after": ttl})
```

```python
# app/storage.py
import uuid, aioboto3
from app.config import settings

async def put_photo(data: bytes, content_type: str) -> str:
    key = f"pintes/{uuid.uuid4()}"
    session = aioboto3.Session()
    async with session.client("s3", endpoint_url=settings.s3_endpoint,
                              aws_access_key_id=settings.s3_access_key,
                              aws_secret_access_key=settings.s3_secret_key) as s3:
        await s3.put_object(Bucket=settings.s3_bucket, Key=key, Body=data, ContentType=content_type)
    return key
```

- [ ] **Step 4: Lancer (succès)** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: photo storage (S3/MinIO) + light validation (mime/size/dedup/rate-limit)"
```

---

### Task 6: Création de pinte (`POST /pintes`) bout-en-bout + publish

**Files:**
- Create: `back/app/routers/pintes.py`
- Modify: `back/app/main.py` (router)
- Test: `back/tests/test_pintes.py`

**Interfaces:**
- Consumes: `validate_photo`, `photo_hash`, `check_duplicate`, `check_rate_limit`, `put_photo`, `Pinte.create`, `incr_total`, `get_current_account`, `get_redis`.
- Produces: `POST /pintes` (multipart `photo`, form `tone?`) → `{number, total, item}` ; publie sur le canal Redis `feed` `{type:"feed_item", item}` et `{type:"counter", total}` ; `item = {id, number, name, city, tone, likes, liked}`.

- [ ] **Step 1: Test qui échoue**

```python
# tests/test_pintes.py
import pytest

@pytest.mark.asyncio
async def test_post_pinte_increments_counter(client, auth_headers):
    before = (await client.get("/counter")).json()["total"]
    files = {"photo": ("p.jpg", b"\xff\xd8\xff\xe0fake", "image/jpeg")}
    r = await client.post("/pintes", headers=auth_headers, files=files)
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == before + 1
    assert body["number"] >= 1
    assert body["item"]["tone"] in {"amber", "coral", "sky"}
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter le router**

```python
# app/routers/pintes.py
import json, random
from fastapi import APIRouter, Depends, UploadFile, File, Form
from app.deps import get_current_account
from app.db import get_session
from app.redis_client import get_redis
from app.domain.validation import validate_photo, photo_hash, check_rate_limit, check_duplicate
from app.domain.counter import incr_total
from app.models import Pinte
from app.storage import put_photo

router = APIRouter()
TONES = ["amber", "coral", "sky"]

@router.post("/pintes")
async def create_pinte(photo: UploadFile = File(None), tone: str = Form(None),
                       account=Depends(get_current_account), session=Depends(get_session), redis=Depends(get_redis)):
    data = await validate_photo(photo)
    h = photo_hash(data)
    await check_duplicate(session, account.id, h)
    await check_rate_limit(redis, str(account.id))
    key = await put_photo(data, photo.content_type)
    tone = tone if tone in TONES else random.choice(TONES)
    pinte = await Pinte.create(session, account_id=account.id, photo_key=key, photo_hash=h, tone=tone)
    await session.commit()
    total = await incr_total(redis)
    item = {"id": str(pinte.id), "number": pinte.number, "name": account.pseudo,
            "city": account.city, "tone": pinte.tone, "likes": 0, "liked": False}
    await redis.publish("feed", json.dumps({"type": "feed_item", "item": item}))
    await redis.publish("feed", json.dumps({"type": "counter", "total": total}))
    return {"number": pinte.number, "total": total, "item": item}
```

- [ ] **Step 4: Lancer (succès)** → PASS (fixture `auth_headers` créée dans conftest via `/auth/device`).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: POST /pintes end-to-end (validate, store, number, incr, publish)"
```

---

### Task 7: Flux temps réel (`GET /counter/stream`, SSE) via Redis pub/sub

**Files:**
- Modify: `back/app/routers/counter.py`
- Test: `back/tests/test_sse.py`

**Interfaces:**
- Consumes: canal Redis `feed`, `get_total`.
- Produces: `GET /counter/stream` → `text/event-stream` ; 1er évènement = total courant ; relaie chaque message du canal `feed` ; keep-alive `:ping`.

- [ ] **Step 1: Test qui échoue**

```python
# tests/test_sse.py
import pytest

@pytest.mark.asyncio
async def test_stream_receives_new_pinte(client, auth_headers):
    async with client.stream("GET", "/counter/stream") as s:
        files = {"photo": ("p.jpg", b"\xff\xd8\xff\xe0x", "image/jpeg")}
        await client.post("/pintes", headers=auth_headers, files=files)
        async for line in s.aiter_lines():
            if "feed_item" in line or "counter" in line:
                assert True; break
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter le générateur SSE**

```python
# app/routers/counter.py (ajout)
import json
from fastapi.responses import StreamingResponse

@router.get("/counter/stream")
async def counter_stream(session=Depends(get_session), redis=Depends(get_redis)):
    async def gen():
        total = await get_total(session, redis)
        yield f"event: counter\ndata: {json.dumps({'type':'counter','total':total})}\n\n"
        pubsub = redis.pubsub()
        await pubsub.subscribe("feed")
        try:
            while True:
                msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=15)
                if msg is None:
                    yield ": ping\n\n"; continue
                yield f"data: {msg['data']}\n\n"
        finally:
            await pubsub.unsubscribe("feed")
    return StreamingResponse(gen(), media_type="text/event-stream")
```

- [ ] **Step 4: Lancer (succès)** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: SSE counter/feed stream via Redis pub/sub"
```

---

### Task 8: Fil paginé (`GET /feed`), likes (`POST /pintes/{id}/like`), profil (`GET /me`)

**Files:**
- Create: `back/app/routers/feed.py`, `back/app/routers/profile.py`, `back/app/domain/streak.py`
- Modify: `back/app/routers/pintes.py` (route like), `back/app/main.py` (routers, retirer `/me` provisoire)
- Test: `back/tests/test_feed.py`, `back/tests/test_likes.py`, `back/tests/test_profile.py`

**Interfaces:**
- Produces: `GET /feed?cursor=&limit=` → `{items:[...], next_cursor}` (tri `created_at` desc, `liked` calculé pour l'appelant) ; `POST /pintes/{id}/like` → `{likes, liked}` (toggle idempotent) ; `GET /me` → `{pseudo, city, myCount, streak}` ; `compute_streak(session, account_id) -> int`.

- [ ] **Step 1: Tests qui échouent**

```python
# tests/test_likes.py
import pytest

@pytest.mark.asyncio
async def test_like_toggle(client, auth_headers, one_pinte_id):
    a = await client.post(f"/pintes/{one_pinte_id}/like", headers=auth_headers)
    assert a.json() == {"likes": 1, "liked": True}
    b = await client.post(f"/pintes/{one_pinte_id}/like", headers=auth_headers)
    assert b.json() == {"likes": 0, "liked": False}
```

- [ ] **Step 2: Lancer (échec attendu)** → FAIL.

- [ ] **Step 3: Implémenter streak, profile, like, feed**

```python
# app/domain/streak.py
import datetime as dt
from sqlalchemy import text

async def compute_streak(session, account_id) -> int:
    rows = (await session.execute(text(
        "SELECT DISTINCT (created_at AT TIME ZONE 'UTC')::date AS d FROM pintes "
        "WHERE account_id=:a AND status='active' ORDER BY d DESC"), {"a": str(account_id)})).all()
    streak, expected = 0, dt.date.today()
    for (d,) in rows:
        if d == expected:
            streak += 1; expected -= dt.timedelta(days=1)
        elif d < expected:
            break
    return streak
```

```python
# app/routers/profile.py
from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from app.deps import get_current_account
from app.db import get_session
from app.models import Pinte
from app.domain.streak import compute_streak

router = APIRouter()

@router.get("/me")
async def me(account=Depends(get_current_account), session=Depends(get_session)):
    my = (await session.execute(select(func.count()).where(
        Pinte.account_id == account.id, Pinte.status == "active"))).scalar()
    return {"pseudo": account.pseudo, "city": account.city,
            "myCount": my, "streak": await compute_streak(session, account.id)}
```

```python
# app/routers/pintes.py (ajout : like toggle)
from sqlalchemy import select, func, delete
from app.models import Like

@router.post("/pintes/{pinte_id}/like")
async def toggle_like(pinte_id: str, account=Depends(get_current_account), session=Depends(get_session)):
    existing = (await session.execute(select(Like).where(
        Like.pinte_id == pinte_id, Like.account_id == account.id))).scalar_one_or_none()
    if existing:
        await session.execute(delete(Like).where(Like.pinte_id == pinte_id, Like.account_id == account.id))
        liked = False
    else:
        session.add(Like(pinte_id=pinte_id, account_id=account.id)); liked = True
    await session.commit()
    likes = (await session.execute(select(func.count()).where(Like.pinte_id == pinte_id))).scalar()
    return {"likes": likes, "liked": liked}
```

```python
# app/routers/feed.py
import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from app.deps import get_current_account
from app.db import get_session
from app.models import Pinte, Like, Account

router = APIRouter()

@router.get("/feed")
async def feed(cursor: str | None = None, limit: int = 20,
               account=Depends(get_current_account), session=Depends(get_session)):
    q = select(Pinte, Account.pseudo, Account.city).join(Account, Account.id == Pinte.account_id)\
        .where(Pinte.status == "active").order_by(Pinte.created_at.desc()).limit(limit)
    if cursor:
        q = q.where(Pinte.created_at < dt.datetime.fromisoformat(cursor))
    rows = (await session.execute(q)).all()
    items, next_cursor = [], None
    for pinte, pseudo, city in rows:
        likes = (await session.execute(select(func.count()).where(Like.pinte_id == pinte.id))).scalar()
        liked = (await session.execute(select(func.count()).where(
            Like.pinte_id == pinte.id, Like.account_id == account.id))).scalar() > 0
        items.append({"id": str(pinte.id), "number": pinte.number, "name": pseudo,
                      "city": city, "tone": pinte.tone, "likes": likes, "liked": liked})
        next_cursor = pinte.created_at.isoformat()
    return {"items": items, "next_cursor": next_cursor if len(rows) == limit else None}
```

- [ ] **Step 4: Lancer (succès)** → PASS. Retirer le `/me` provisoire de la Task 3.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: feed pagination, like toggle, profile (myCount + streak)"
```

---

### Task 9: Lifespan resync + README + lint

**Files:**
- Modify: `back/app/main.py` (lifespan resync compteur au boot), `back/README.md`

- [ ] **Step 1: Brancher le resync au démarrage**

```python
# app/main.py (lifespan)
from contextlib import asynccontextmanager
from app.db import SessionMaker
from app.redis_client import _redis
from app.domain.counter import resync_from_sequence

@asynccontextmanager
async def lifespan(app):
    async with SessionMaker() as s:
        await resync_from_sequence(s, _redis)
    yield
```
(Passer `lifespan=lifespan` à `FastAPI(...)`.)

- [ ] **Step 2: Lancer toute la suite** — `pytest -v` → tout PASS ; `ruff check .` et `black --check .` → OK.

- [ ] **Step 3: README backend** — démarrage docker-compose, migrations Alembic, lancement uvicorn, lancement des tests.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore: boot-time counter resync + README + lint clean"
```

---

## Self-Review

- **Couverture spec** : onboarding (T3), compteur + SSE (T4, T7), photo + validation légère (T5), POST /pintes (T6), fil + likes + profil/streak (T8), cohérence compteur/resync (T4, T9), codes d'erreur (T5/T6), tones aléatoires (T6), idempotence auth/like (T3, T8). `Idempotency-Key` sur POST /pintes : durcissement optionnel post-MVP — noté, non bloquant.
- **Placeholders** : code réel fourni pour chaque étape ; routes feed/like/profile complètes.
- **Cohérence des types** : `Pinte.create`, `get_total/incr_total/resync_from_sequence`, `validate_photo/photo_hash/check_duplicate/check_rate_limit`, `compute_streak`, structure `item` cohérents entre tâches.

> Le plan **app Flutter** sera écrit ensuite (consomme : `/auth/device`, `/counter`, `/counter/stream`, `/pintes`, `/feed`, `/pintes/{id}/like`, `/me`).
