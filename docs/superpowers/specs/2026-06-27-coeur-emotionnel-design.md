# Tchin.beer — Spec « Cœur émotionnel » (incrément 1)

> Nom de l'app : **Tchin.beer** (prononcé « Tchin »). Working title historique : « Le Million de Pintes ».

> Date : 2026-06-27
> Statut : validé en brainstorming
> Contexte produit complet : `docs/design_handoff_pinte_app/CONCEPT_SUMMARY.md`
> Design hi-fi de référence : `docs/design_handoff_pinte_app/README.md` + `Pinte App Prototype.dc.html`

## 1. Objectif de l'incrément

Livrer le **cœur émotionnel** de l'app : une communauté qui voit son **compteur mondial monter en temps réel** en postant des photos de pintes, et un **fil commun** où chaque pinte apparaît. C'est le squelette jouable et démontrable.

**Inclus** : onboarding léger (pseudo + ville, compte anonyme appareil), compteur mondial temps réel, capture photo d'une pinte → +1 validé, fil commun avec likes, profil léger (mes pintes, streak, ville).

**Exclus (incréments suivants)** : classements villes/régions, derbys, badges, achats in-app (Fondateur / Pinte+ / cosmétiques), modération avancée / IA, internationalisation.

## 2. Décisions de cadrage (verrouillées)

| Sujet | Décision |
|---|---|
| Périmètre | Cœur émotionnel (compteur + capture + fil + profil léger) |
| Temps réel | **SSE (Server-Sent Events)** depuis FastAPI + **Redis pub/sub** pour le fan-out multi-instances |
| Auth | Compte **anonyme lié à l'appareil** : pseudo + ville, `device_token` en Bearer |
| Photo | **Obligatoire**, **validation légère AVANT le +1** (présence, anti-doublon par hash, rate-limit) |
| Source de vérité compteur | **Postgres** (séquence pour numéroter), **Redis** = miroir rapide + relais SSE |
| Stockage photos | Stockage objet **S3-compatible** (MinIO en dev, S3/Cloudflare R2 en prod) |
| État Flutter | **Riverpod** |
| Dépôts git | **3 dépôts indépendants** : `app/` (Flutter), `back/` (FastAPI), `web/` (site, hors périmètre). `docker-compose` de dev dans `back/`. |

## 3. Architecture

```
┌─────────────────┐      HTTPS REST + SSE       ┌──────────────────────┐
│  App Flutter    │ ─────────────────────────► │   FastAPI (backend)  │
│  (iOS/Android)  │ ◄───── flux SSE ─────────── │                      │
└─────────────────┘                            │  ┌────────┬────────┐  │
   upload photo (multipart) ───────────────►   │  │Postgres│ Redis  │  │
                                               │  └────────┴────────┘  │
                                               │   stockage objet (S3) │
                                               └──────────────────────┘
```

### 3.1 Flutter (`app/`)
- Couches : `ui` (écrans/widgets) · `state` (providers Riverpod) · `data` (repositories + client API/SSE) · `models`.
- Navigation : 3 onglets pour cet incrément — **Accueil · Fil · Profil** — + 2 overlays plein écran — **Capture · Succès**. Barre de nav conçue pour accueillir l'onglet **Villes** plus tard, avec le **(+) flottant central**.
- Design tokens du handoff centralisés dans un `theme` (couleurs `#FFF4E0`/`#FFFBF2`/`#FF6A3D`/`#F4A722`/`#1AA3D6`…, polices **Bricolage Grotesque** display + **Hanken Grotesk** UI, rayons/ombres/espacements). Cible mobile portrait.
- Compteur formaté `fr-FR` (séparateurs de milliers en espaces fines).

### 3.2 FastAPI (`back/`)
- Async de bout en bout (`async def`, Postgres async via SQLAlchemy async / `asyncpg`).
- Découpage par domaine : `auth`, `pintes`, `feed`, `counter`, `media`.
- Postgres = vérité ; Redis = compteur cache + pub/sub SSE ; stockage objet pour les photos.
- `docker-compose` de dev : `api` + `postgres` + `redis` + `minio`.
- Lint/format : `ruff` + `black`.

## 4. Modèle de données (Postgres)

**`accounts`**
| colonne | type | note |
|---|---|---|
| `id` | uuid PK | |
| `device_token` | text unique | secret généré au 1er lancement, auth Bearer |
| `pseudo` | text | choisi à l'onboarding |
| `city` | text | ville déclarée (libre pour le MVP) |
| `created_at` | timestamptz | |

**`pintes`**
| colonne | type | note |
|---|---|---|
| `id` | uuid PK | |
| `number` | bigint unique | numéro mondial via séquence `pintes_number_seq` (`nextval`) |
| `account_id` | uuid FK → accounts | auteur |
| `photo_key` | text | clé objet S3/MinIO |
| `photo_hash` | text | hash anti-doublon |
| `tone` | text | `amber` / `coral` / `sky` (aléatoire à la création) |
| `status` | text | `active` / `removed` (modération a posteriori) |
| `created_at` | timestamptz | indexé (tri du fil) |

**`likes`**
| colonne | type | note |
|---|---|---|
| `pinte_id` | uuid FK → pintes | |
| `account_id` | uuid FK → accounts | |
| `created_at` | timestamptz | |
| | | unicité `(pinte_id, account_id)` |

**Valeurs dérivées (non stockées)** :
- **Compteur global** : `last_value` de `pintes_number_seq` (vérité) ; `counter:total` Redis = miroir.
- **`myCount`** : `COUNT(*)` des pintes `active` du compte.
- **`streak`** : nombre de jours consécutifs (jusqu'à aujourd'hui) avec ≥ 1 pinte — **calculé à la volée**.

## 5. API REST + SSE

Auth par `Authorization: Bearer <device_token>` sauf onboarding.

| Méthode | Route | Rôle |
|---|---|---|
| `POST` | `/auth/device` | Crée un compte (pseudo + ville) → `device_token` + profil. Idempotent si token déjà fourni. |
| `GET` | `/counter` | Total courant (Redis, fallback séquence). État initial avant le flux. |
| `GET` | `/counter/stream` | **SSE** : `{type:"counter", total}` à chaque pinte ; `{type:"feed_item", item}` pour les nouvelles pintes. Keep-alive `:ping`. Reconnexion via `Last-Event-ID` → renvoie le total courant. |
| `POST` | `/pintes` | **multipart** (photo + `tone` optionnel, `Idempotency-Key` optionnel). Valide → insère (numéro séquence) → `INCR` Redis → `PUBLISH` → `{number, total, item}`. |
| `GET` | `/feed?cursor=&limit=` | Fil paginé (curseur `created_at`/`id`), `liked` calculé pour l'appelant. |
| `POST` | `/pintes/{id}/like` | Toggle like idempotent → `{likes, liked}`. |
| `GET` | `/me` | Profil : `pseudo`, `city`, `myCount`, `streak`. |

### 5.1 Parcours « ajouter une pinte »
```
[Accueil] CTA / [+] → [Overlay Capture] photo → tap déclencheur
  → POST /pintes (multipart) → validation légère → séquence +1, INCR Redis, PUBLISH
  → réponse {number, total, item} → [Overlay Succès] "Pinte n° {number} validée ! +1"
  → en parallèle, SSE diffuse counter + feed_item à toute la communauté
```
- **Succès joué sur la réponse serveur** (numéro réel garanti), pas en pur optimiste.
- Le compteur de l'écran Accueil est piloté par le **flux SSE** (cohérent pour tous).
- **Like** : toggle optimiste (±1 immédiat) réconcilié avec la réponse.

## 6. Anti-triche léger (avant le +1)

- Photo présente, non vide, type MIME autorisé (jpeg/png/webp), taille max.
- `photo_hash` absent des pintes récentes du même compte (fenêtre ex. 24 h) → sinon `DUPLICATE_PHOTO`.
- Rate-limit par compte via Redis (ex. max 1 pinte / 60 s, et un plafond / jour) → sinon `RATE_LIMITED` (+ `retry_after`).

## 7. Gestion des erreurs & cas limites

**Backend**
- Validation refusée → `409` avec `code` (`DUPLICATE_PHOTO`, `RATE_LIMITED`, `PHOTO_MISSING`, `PHOTO_INVALID`).
- Upload trop gros / type interdit → `413` / `415`.
- Stockage objet KO après début d'insertion → transaction annulée (jamais de pinte sans photo).
- Token absent/inconnu → `401`.
- Cohérence compteur : Redis resynchronisé depuis `last_value` au démarrage et périodiquement ; on ne diffuse que des **incréments monotones** (jamais de recul).
- Idempotence : `/auth/device`, `/like` (toggle), `POST /pintes` via `Idempotency-Key` optionnel (anti double-soumission sur retry).

**Flutter**
- Réseau coupé pendant l'envoi → état « réessayer » ; **jamais de Succès non confirmé**.
- SSE tombé → bandeau « reconnexion… », reprise auto du compteur.
- Fil : pull-to-refresh, pagination curseur, états liste vide / erreur.
- Permission caméra refusée → écran d'explication + lien réglages.

## 8. Tests & qualité

**Backend (pytest, TDD sur la logique critique)**
- Unitaires : validation anti-triche (doublon, rate-limit), calcul streak, attribution du numéro via séquence.
- Intégration (Postgres + Redis de test) : `POST /pintes` bout-en-bout, `/feed` pagination, toggle `/like`, idempotence.
- SSE : une pinte créée par un client est diffusée à un autre client abonné.

**Flutter**
- `state` : providers Riverpod (like optimiste, état d'envoi pinte, réconciliation).
- Widget tests : Accueil / Fil / Capture / Succès.
- Golden léger : compteur formaté `fr-FR`.

**Outils** : `ruff` + `black` (Python) ; `dart format` + `flutter analyze` (Dart).

## 9. Hors périmètre (rappel)

Classements villes/régions, derbys, badges, achats in-app, modération avancée/IA, i18n, site web. Chacun fera l'objet de son propre spec.

## 10. Décisions d'implémentation Flutter (ajout 2026-06-28)

> Le backend (`back/`) est livré (Tasks 1–9, tests verts). Décisions verrouillées pour le plan d'app Flutter :

| Sujet | Décision |
|---|---|
| Capture photo | **Viseur in-app custom** via le plugin `camera` (équerres de cadrage, déclencheur custom, preview live) — fidèle au handoff. `permission_handler` pour la permission caméra. |
| Toolchain | **Flutter/Dart non installé** sur la machine. Le plan est écrit maintenant et exécutable dès que le SDK est installé (analogue au blocage Docker du backend). |
| HTTP / SSE | Dépendance unique `http` : REST (`MultipartRequest` pour l'upload) **et** client SSE maison (`Client.send` streamé, parsing des lignes `data:`, reconnexion via `Last-Event-ID`). |
| Packages | `flutter_riverpod` 2.x (Notifier/AsyncNotifier, sans codegen) · `flutter_secure_storage` (device_token) · `intl` (format fr-FR) · `google_fonts` (Bricolage Grotesque + Hanken Grotesk ; bundler en prod). |
| Périmètre app | Onboarding → onglets **Accueil · Fil · Profil** + overlays **Capture · Succès**. Slot **Villes** réservé dans la nav mais inerte ; cartes Fondateur/Pinte+ = teasers statiques non interactifs (fidélité). |
| Photos du fil | `/feed` n'expose pas d'URL photo → le fil affiche le **placeholder rayé par teinte** (amber/coral/sky) comme le design hifi. Affichage des vraies photos = incrément ultérieur. |
| Connectivité dev | Base URL configurable (émulateur Android `10.0.2.2:8000`, simu iOS `localhost:8000`) contre la stack `back/`. |
| Dépôt | Nouveau dépôt git indépendant `app/` (frère de `back/`). |
