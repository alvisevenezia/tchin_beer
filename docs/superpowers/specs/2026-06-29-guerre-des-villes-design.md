# La guerre des villes — Design (MVP)

> Spec produit + technique pour le classement des villes de **Tchin.beer**.
> Accompagne la maquette `docs/Pinte App Prototype.dc.html` (écran « La guerre des villes »).
> Date : 2026-06-29.

## 1. Objectif

Le moteur d'engagement central du concept : **ta ville contre toutes les autres**. Chaque pinte
compte +1 pour la ville de son auteur ; un classement temps réel, **remis à zéro chaque jour et
chaque semaine**, donne une nouvelle chance de gagner à chaque réveil.

## 2. Périmètre

**Inclus (MVP) :**
- Classement **par ville**, deux fenêtres : **Aujourd'hui** et **Cette semaine**.
- **Temps réel** : le classement se met à jour en ~1 s après n'importe quelle pinte.
- **Rang de ta ville** mis en avant (surlignage + rang explicite, même hors top-N).
- Écran « Villes » fidèle à la maquette ; branchement de l'onglet déjà présent (aujourd'hui inerte).
- Stat **« rang ville »** du profil renseignée (fenêtre semaine).

**Hors périmètre (plus tard) :**
- **Régions** (niveau 2) — nécessite un mapping ville→région.
- **Derby** réel (duels programmés) — la carte Derby est un **teaser statique** « bientôt »,
  conforme à la maquette.
- Ligne « ta ville cette semaine » sur l'écran Accueil.
- Resets internationaux multi-fuseaux (MVP : **Europe/Paris**).

## 3. Idée directrice — temps réel & reset sans cron

On stocke des **sorted sets Redis horodatés**, un par fenêtre :

- `rank:day:<YYYY-MM-DD>` — membre = clé ville, score = nombre de pintes du jour.
- `rank:week:<GGGG-Www>` — idem pour la semaine ISO.

Les dates/semaines sont calculées en **Europe/Paris**. Comme la **période est dans le nom de la
clé**, le « reset » quotidien/hebdo se produit automatiquement au changement de date : la nouvelle
clé démarre vide. **Aucun job cron n'est nécessaire.** Un **TTL** sur chaque clé (jour : 48 h,
semaine : 9 j) garantit l'auto-nettoyage.

**Postgres reste la source de vérité.** Si une clé manque (démarrage à froid, `FLUSHDB`), elle est
**reconstruite** en agrégeant la table `pintes` sur la fenêtre courante. C'est exactement le pattern
déjà utilisé pour le compteur (`domain/counter.py::resync_from_sequence`).

## 4. Backend

### 4.1 `app/domain/rankings.py` (nouveau)

```
DAY_TTL   = 48 h
WEEK_TTL  = 9 jours
TZ        = ZoneInfo("Europe/Paris")
DISPLAY_KEY = "city:display"           # hash: cityKey -> nom affiché

normalize_city(s) -> str
    # trim, casefold, suppression des accents (unicodedata NFKD),
    # compactage des espaces. Ex. "  Saint-Étienne " -> "saint-etienne".
    # Chaîne vide -> ignorée (jamais classée).

period_keys(now) -> (day_key, week_key)
    # now converti en Europe/Paris ; week via isocalendar() -> "GGGG-Www".

window_start(period, now) -> datetime (aware, UTC)
    # day  : minuit Europe/Paris du jour courant, converti UTC.
    # week : lundi 00:00 Europe/Paris de la semaine ISO courante, converti UTC.

async rebuild(session, redis, period) -> str
    # SELECT a.city, COUNT(*) FROM pintes p JOIN accounts a ON a.id = p.account_id
    #   WHERE p.created_at >= window_start AND p.status = 'active' GROUP BY a.city
    # Agrège par normalize_city (plusieurs orthographes -> même clé), écrit le ZSET
    # (pipeline : DEL puis ZADD), pose le TTL, peuple DISPLAY_KEY. Retourne la key Redis.

async ensure_built(session, redis, period) -> str
    # Renvoie la key ; si elle n'existe pas (EXISTS == 0), rebuild d'abord.

async bump(session, redis, city) -> None
    # Appelé à chaque pinte. ensure_built(jour) + ensure_built(semaine),
    # ZINCRBY +1 sur les deux, HSET DISPLAY_KEY[cityKey] = city (orthographe de l'auteur),
    # refresh des TTL. Ville vide -> no-op.

async top_cities(session, redis, period, limit) -> list[dict]
    # ensure_built -> ZREVRANGE 0..limit-1 WITHSCORES -> [{key, name, count, rank}]
    # name via HGET DISPLAY_KEY (fallback : key.title()).

async city_rank(session, redis, period, city) -> dict | None
    # ensure_built -> cityKey = normalize_city(city) ; ZREVRANK + ZSCORE.
    # None si ville vide ou absente du classement.
```

Notes :
- `bump` reçoit la session pour pouvoir reconstruire si la clé manque au moment du post
  (évite un ZSET partiel ne contenant qu'une ville).
- Le rang est 0-based côté Redis ; on expose **1-based** dans l'API.

### 4.2 `app/routers/rankings.py` (nouveau)

```
GET /rankings?period=day|week&limit=10        (auth requise)

period invalide  -> 422 (Query enum "day"|"week", défaut "day")
limit            -> borné [1, 50], défaut 10

Réponse 200 :
{
  "period": "day",
  "cities": [ { "key": "toulouse", "name": "Toulouse", "count": 4812, "rank": 1 }, ... ],
  "me":     { "key": "lyon", "name": "Lyon", "count": 4530, "rank": 2 }   // ou null
}
```

`me` = rang de la ville du compte appelant (`get_current_account().city`), **même hors top-N**.
`null` si la ville n'a aucune pinte sur la fenêtre.

### 4.3 `app/routers/pintes.py` (modif)

Après `total = await incr_total(redis)` et la construction de `item`, avant/avec les `publish`
existants :

```
await rankings.bump(session, redis, account.city)
await redis.publish("feed", json.dumps({"type": "rankings_changed"}))
```

Le message `rankings_changed` est **un simple signal** (sans payload) relayé par le flux SSE
existant `/counter/stream` (qui republie tout message du canal `feed`).

### 4.4 `app/main.py` (modif)

Inclure `rankings.router`. Pas de resync au boot nécessaire (les lectures reconstruisent à la
demande), mais on peut ajouter un rebuild best-effort jour+semaine dans le `lifespan` pour
« réchauffer » le cache — optionnel.

## 5. Temps réel côté app

Le SSE `/counter/stream` relaie déjà chaque message du canal `feed`. Le `CounterController`
consomme déjà ce flux. On ajoute un cas :

```
case 'rankings_changed':
    ref.read(rankingsControllerProvider.notifier).onRemoteChange();
```

`onRemoteChange()` **debounce ~600 ms** puis appelle `refresh()` (re-fetch `GET /rankings` pour la
période actuellement affichée). Lecture ZSET rapide ; inclut le `me` propre à l'utilisateur. Pas de
diffusion de gros payloads par utilisateur. Les types inconnus restent ignorés par le
`CounterController` (le `switch` n'a pas de `default`).

## 6. Frontend

### 6.1 Modèle — `app/lib/models/ranking.dart` (nouveau)

```
class CityRank { final String key, name; final int count, rank; fromJson(...) }
class Rankings {
  final String period;            // 'day' | 'week'
  final List<CityRank> cities;
  final CityRank? me;
  fromJson(...)
}
```

### 6.2 `app/lib/data/api_client.dart` (modif)

```
Future<Rankings> getRankings({String period = 'day', int limit = 10}) async { ... GET /rankings ... }
```

### 6.3 État — `app/lib/state/rankings_controller.dart` (nouveau)

`Notifier<RankingsUiState>` où `RankingsUiState { String period; AsyncValue<Rankings> data; }`.

- `build()` : période initiale `day`, déclenche un premier `refresh()`.
- `setPeriod(p)` : change la période et `refresh()`.
- `refresh()` : `data = AsyncLoading` (en préservant la valeur précédente) → `getRankings` →
  `AsyncData`/`AsyncError`.
- `onRemoteChange()` : (re)arme un `Timer` de 600 ms qui appelle `refresh()` ; coalesce les rafales.
- `ref.onDispose` annule le timer.

Provider : `rankingsControllerProvider`.

### 6.4 `app/lib/state/counter_controller.dart` (modif)

Ajout du `case 'rankings_changed'` dans `_listen` (voir §5).

### 6.5 Écran — `app/lib/ui/rankings_screen.dart` (nouveau)

Reproduction fidèle de la maquette (valeurs extraites du prototype) :

- Padding `20, 22, 30`. Titre `Bricolage 800`, 30 px, `letter-spacing -0.02em`, sur deux lignes :
  « La guerre / des villes » (via `displayStyle`).
- **Pills période** (gap 8) : actif = texte `#fff` sur `ink (#2A1A0D)` ; inactif = `muted (#9A865F)`
  sur `foam (#FFFBF2)` ; padding `8×18`, radius 100. Tap → `setPeriod`.
- **Liste** (`AsyncValue.when`), gap 18, une ligne par ville :
  - En-tête `space-between`, baseline. Top 3 : poids 700, 17 px, couleur `ink`.
    Rang 4+ : poids 600, 16 px, couleur `#6A573C`.
  - Gauche : médaille (`🥇/🥈/🥉`) pour 1–3, sinon `«N · »` ; puis le nom de la ville.
    Si `city.key == me?.key` → pill corail **« ta ville »** (12 px, `#fff` sur `coral`, radius 100).
  - Droite : `count` formaté fr-FR (`formatCountFr`).
  - **Barre** : piste radius 100 sur `rail (#ECDCBF)`, hauteur 16 (top 3) / 14 (rang 4+).
    Largeur = `count / cities.first.count` (relative au 1ᵉʳ). Couleur de remplissage :
    rang 1 `amber (#F4A722)`, rang 2 `#FF8A3D`, rang 3 `coral (#FF6A3D)`, rang 4+ `sky (#1AA3D6)`.
- **Carte Derby** (teaser statique, margin-top 24) : fond `#241308`, radius 18, padding `18×20`.
  Titre `Bricolage 800` 18 px `#FFCB6B` « ⚔️ Derby du week-end » ; sous-texte 15 px `#FFE3C2`
  « Bientôt : des duels programmés entre villes. » (texte teaser, pas la donnée live de la maquette).
- États : `loading` → spinner ; `error` → message + bouton « Réessayer » (appelle `refresh`).
  Liste vide (aucune pinte sur la fenêtre) → encart « Personne n'a encore trinqué aujourd'hui.
  Sois le premier ! ».

L'écran enveloppe son contenu dans `SafeArea` + `SingleChildScrollView` (cohérent avec Home).

### 6.6 `app/lib/ui/app_shell.dart` (modif)

L'onglet « Villes » (index 3) est aujourd'hui inerte (`if (i == 3) return;`). On l'active :
ajouter `const RankingsScreen()` à l'`IndexedStack` et router le tap de l'onglet 3 vers cet index.
Réindexation : `IndexedStack` devient `[Home, Feed, Rankings, Profile]` ; le mapping de la barre
(slots 0,1, FAB=2, Villes=3, Profil=4) est ajusté en conséquence. Le FAB central et les autres
onglets restent inchangés visuellement.

### 6.7 `app/lib/ui/profile_screen.dart` (modif)

Le stat « rang ville » affiche aujourd'hui « — ». On le renseigne depuis
`ref.watch(rankingsControllerProvider)` (fenêtre **semaine**) : si `me != null` → `«Ne»`
(`me.rank` + exposant), sinon « — ». Lecture seule, pas de changement de période depuis le profil
(le profil n'altère pas l'état partagé : il lit `me` de la donnée déjà chargée, et déclenche au
besoin un `getRankings(period:'week')` dédié — voir note ci-dessous).

> Note : le `rankingsControllerProvider` porte une seule période à la fois (celle de l'écran
> Villes). Pour le profil, on lit un provider dérivé `myWeekCityRankProvider`
> (`FutureProvider`) qui fait un `getRankings(period:'week', limit:1)` et n'expose que `me`.
> Léger, indépendant de la période affichée sur l'écran Villes.

## 7. Normalisation des villes — règles

- Clé = NFKD sans diacritiques + casefold + trim + espaces compactés.
- Le **nom affiché** vient du hash `city:display` (orthographe d'un vrai utilisateur de la ville,
  dernière écriture gagnante) ; fallback `key.title()`.
- Conséquence assumée MVP : « Paris » et « paris » fusionnent (bien) ; « Saint-Étienne » et
  « Saint Etienne » fusionnent aussi (bien). Pas de gestion des homonymes (une seule « Saint-Denis »).

## 8. Tests

### 8.1 Backend (`back/tests/test_rankings.py`, pytest, vrai PG + Redis via conftest)

- `normalize_city` : accents, casse, espaces, trait d'union, chaîne vide.
- `GET /rankings` : poster des pintes depuis plusieurs comptes/villes → vérifier l'ordre, les
  `count`, les `rank` 1-based, et `me` (ville de l'appelant) y compris hors top-N.
- Fenêtre : `me == null` quand la ville n'a aucune pinte sur la période.
- Robustesse : après `FLUSHDB`, `GET /rankings` reconstruit correctement depuis Postgres.
- Temps réel : un `POST /pintes` publie bien `rankings_changed` (vérif via abonnement Redis ou via
  l'incrément observable sur un second `GET /rankings`).

### 8.2 Flutter (`app/test/rankings_test.dart`, MockClient comme l'existant)

- `RankingsController` : `setPeriod` recharge ; `onRemoteChange` déclenche un seul `refresh`
  après debounce (coalescing) ; une erreur réseau passe en `AsyncError` sans crasher.
- Widget `RankingsScreen` : rend les lignes, surligne « ta ville », la bascule de période appelle
  `setPeriod`, l'état vide affiche l'encart.

### 8.3 Vérification visuelle

Capture phone (392×846) de l'écran Villes (or amber/corail/ciel, podium, « ta ville », Derby) pour
confirmer la fidélité à la maquette — comme fait pour le splash + login.

## 9. Critères d'acceptation

1. `GET /rankings?period=day|week` renvoie villes ordonnées + `me`, rangs 1-based.
2. Poster une pinte met à jour le classement de l'app en ~1 s (jour **et** semaine) sans
   rafraîchissement manuel.
3. Le classement « Aujourd'hui » repart de zéro au passage de minuit Europe/Paris (par construction
   des clés) ; « Cette semaine » au lundi.
4. L'onglet « Villes » ouvre l'écran ; le profil affiche le rang de ville (semaine).
5. `flutter analyze` propre, suites Flutter + pytest vertes.

## 10. Fichiers touchés

**Backend (nouveaux)** : `app/domain/rankings.py`, `app/routers/rankings.py`, `tests/test_rankings.py`.
**Backend (modifs)** : `app/routers/pintes.py`, `app/main.py`.
**Frontend (nouveaux)** : `lib/models/ranking.dart`, `lib/state/rankings_controller.dart`,
`lib/ui/rankings_screen.dart`, `test/rankings_test.dart`.
**Frontend (modifs)** : `lib/data/api_client.dart`, `lib/state/counter_controller.dart`,
`lib/ui/app_shell.dart`, `lib/ui/profile_screen.dart`.
