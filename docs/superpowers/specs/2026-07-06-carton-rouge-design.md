# Carton rouge & réactions gratuites — Design

> Spec technique pour l'invalidation communautaire des pintes (« carton rouge »), le tracking des
> vues qui le sous-tend, et le passage de `fire`/`star` en réactions gratuites.
> Accompagne trois correctifs annexes (streak, heure de post, logo onboarding) décrits en §8,
> traités en implémentation directe (pas de design nécessaire, faible ambiguïté).
> Date : 2026-07-06.

## 1. Objectif

Donner à la communauté un moyen de signaler qu'une pinte est invalide (photo trichée, hors-sujet,
etc.) via un **carton rouge**, avec un seuil basé sur la proportion de vues plutôt qu'un compte
absolu, pour éviter qu'une poignée de votes suffise sur une pinte peu vue. Réversible : si le
ratio repasse sous le seuil (retrait d'un carton, ou simplement plus de vues), la pinte est
revalidée automatiquement.

En parallèle, `fire` et `star` (2 des 5 super-réactions) deviennent gratuites pour tout le monde,
ce qui rend `starter_pack` obsolète.

## 2. Périmètre

**Inclus :**
- Table `views` (vues distinctes par compte/pinte), alimentée automatiquement depuis `/feed`.
- Carton rouge : toggle par compte/pinte (comme `like`), auteur exclu, seuil double
  (absolu + pourcentage des vues), transition `active` ⇄ `invalidated` réévaluée à chaque toggle.
- Pinte `invalidated` : grisée + overlay « Invalidée » dans le feed, exclue des rankings/streak
  (déjà filtrés `status == 'active'`), retirée du compteur « vers le million » (redéfini comme
  `COUNT(active)`, plus depuis la séquence brute).
- Stats profil : nombre de cartons rouges reçus, nombre de pintes invalidées.
- `fire`/`star` gratuites par défaut ; `starter_pack` retiré du catalogue boutique.

**Hors périmètre (plus tard) :**
- Réaction « pouce » de validation communautaire (contrebalance du carton rouge) — reportée,
  ajoute de la complexité UI/engagement à part entière.
- Pénalité automatique au-delà d'un seuil de cartons rouges reçus (juste une stat pour l'instant).
- Décrément du ZSET de rankings de la période en cours quand une pinte de cette période est
  invalidée après coup (limitation acceptée, cohérente avec l'« eventual consistency » déjà
  assumée par `rankings.py`, qui ne se corrige qu'au prochain rebuild).

## 3. Modèle de données

### 3.1 `views` (nouvelle table)

```
pinte_id    UUID  FK pintes.id   PK
account_id  UUID  FK accounts.id PK
created_at  timestamptz  server_default now()
```

Clé composite unique par construction (PK). Une ligne = « ce compte a vu cette pinte au moins une
fois ». Pas de compteur de répétitions : la 2ᵉ apparition dans le feed ne crée rien de plus
(`INSERT ... ON CONFLICT DO NOTHING`).

### 3.2 `red_cards` (nouvelle table)

```
pinte_id    UUID  FK pintes.id   PK
account_id  UUID  FK accounts.id PK
created_at  timestamptz  server_default now()
```

Même forme que `likes` — un carton rouge par compte par pinte, retirable (toggle).

### 3.3 `pintes.status`

Déjà existant (`default="active"`), jusqu'ici jamais réellement utilisé (aucune transition dans le
code actuel — les doublons sont bloqués *avant* création, pas marqués après coup). Ce projet est le
premier à écrire une valeur différente : `"invalidated"`.

### 3.4 Migration (`back/migrations/versions/`)

Nouvelle révision, `down_revision = "g2h3i4j5k6l7"` (dernière en date). Crée `views` et
`red_cards` avec les colonnes ci-dessus + FK + PK composites, symétrique à la migration
`add_reactions` existante. `downgrade()` : `DROP TABLE` des deux dans l'ordre inverse.

## 4. Backend

### 4.1 `app/domain/counter.py` (modifié)

Le total n'est plus dérivé de la séquence Postgres (monotone, jamais décrémentable) mais du
nombre de pintes **actives** :

```python
async def resync_from_db(session, redis) -> int:
    # SELECT COUNT(*) FROM pintes WHERE status = 'active'
    ...
    await redis.set(TOTAL_KEY, total)
    return total

async def get_total(session, redis) -> int:
    v = await redis.get(TOTAL_KEY)
    return int(v) if v is not None else await resync_from_db(session, redis)

async def incr_total(redis) -> int: ...   # inchangé
async def decr_total(redis) -> int:       # nouveau
    return await redis.decr(TOTAL_KEY)
```

`Pinte.number` (numéro de badge, ex. `#482 913`) reste basé sur `pintes_number_seq` — inchangé,
toujours strictement croissant, indépendant du total affiché.

`app/main.py` : renommer l'import/appel `resync_from_sequence` → `resync_from_db` (même usage au
`lifespan`).

### 4.2 `app/domain/moderation.py` (nouveau)

Logique d'invalidation, isolée du routeur pour être testable indépendamment :

```python
RED_CARD_MIN_COUNT = 3
RED_CARD_MIN_RATIO = 0.20

async def red_card_count(session, pinte_id) -> int: ...
async def view_count(session, pinte_id) -> int: ...

def should_invalidate(red_cards: int, views: int) -> bool:
    if views == 0:
        return False
    return red_cards >= RED_CARD_MIN_COUNT and (red_cards / views) >= RED_CARD_MIN_RATIO

async def record_views(session, account_id, pinte_ids: list[str]) -> None:
    # INSERT INTO views (pinte_id, account_id) VALUES ... ON CONFLICT DO NOTHING (bulk).
    # Ne fait aucun filtrage par auteur : la liste reçue est déjà nettoyée par l'appelant
    # (voir §4.3 — feed.py connaît account_id de chaque pinte, pas moderation.py).

async def reevaluate(session, redis, pinte) -> bool:
    """Recalcule le statut d'une pinte après un ajout/retrait de carton rouge.
    Retourne True si le statut a changé (pour déclencher publish + incr/decr)."""
    red = await red_card_count(session, pinte.id)
    views = await view_count(session, pinte.id)
    invalid = should_invalidate(red, views)
    if invalid and pinte.status == "active":
        pinte.status = "invalidated"
        return True
    if not invalid and pinte.status == "invalidated":
        pinte.status = "active"
        return True
    return False
```

### 4.3 `app/routers/feed.py` (modifié)

- Après avoir construit `rows`, appeler `record_views(session, account.id, ids)` une seule fois
  par requête (bulk, pas en boucle par item), où `ids = [pinte.id for pinte, *_ in rows if pinte.account_id != account.id]`
  — le filtrage sur l'auteur se fait ici, côté appelant, puisque `feed.py` a déjà `pinte.account_id`
  sous la main (`moderation.record_views` ne reçoit que des ids déjà filtrés, voir §4.2).
- Ajouter au payload de chaque item :
  - `"posted_at": pinte.created_at.isoformat()`
  - `"invalidated": pinte.status != "active"`
  - `"my_red_card": <bool>` (une sous-requête comme pour `my_reaction`, ou un `IN` groupé)
- Le compte du carton rouge n'est **pas** exposé publiquement (pas de `red_card_count` dans le
  feed) — évite d'encourager le brigading autour d'un chiffre visible ; seule la conséquence
  (`invalidated`) est visible.
- Le filtre `WHERE Pinte.status == "active"` du `SELECT` principal est **retiré** : une pinte
  invalidée doit maintenant apparaître dans le feed (grisée), pas disparaître. Elle reste
  exclue des rankings/streak, qui gardent leur propre filtre `status == 'active'` inchangé.

### 4.4 `app/routers/pintes.py` (modifié)

Nouvel endpoint, même forme que `toggle_like` :

```python
@router.post("/pintes/{pinte_id}/red_card")
async def toggle_red_card(
    pinte_id: str,
    account=Depends(get_current_account),
    session=Depends(get_session),
    redis=Depends(get_redis),
):
    pinte = await session.get(Pinte, pinte_id)
    if pinte.account_id == account.id:
        raise HTTPException(409, {"code": "CANNOT_RED_CARD_OWN_PINTE"})

    existing = ... # SELECT RedCard WHERE pinte_id=... AND account_id=...
    if existing:
        await session.delete(existing)
        mine = False
    else:
        session.add(RedCard(pinte_id=pinte_id, account_id=account.id))
        mine = True

    changed = await reevaluate(session, redis, pinte)
    await session.commit()

    if changed:
        if pinte.status == "invalidated":
            total = await decr_total(redis)
        else:
            total = await incr_total(redis)
        await redis.publish("feed", json.dumps({"type": "counter", "total": total}))
        await redis.publish(
            "feed",
            json.dumps({"type": "pinte_status", "id": pinte_id, "invalidated": pinte.status != "active"}),
        )

    return {"myRedCard": mine, "invalidated": pinte.status != "active"}
```

Le nouvel événement `pinte_status` sur le canal `feed` permet au feed déjà ouvert (via SSE) de
griser une carte en direct sans re-fetch complet — même mécanisme que `feed_item`/`counter`.

### 4.5 `app/routers/shop.py` (modifié)

- `REACTION_PACK_CATALOG` : retirer l'entrée `starter_pack`. `party_pack` inchangé (toujours les
  5 réactions, reste payant pour débloquer `tchin`/`wave`/`confetti`).
- `FREE_REACTIONS = ["fire", "star"]` exporté pour réutilisation par `profile.py`.

### 4.6 `app/routers/profile.py` (modifié)

- `available_reactions` dans `GET /me` : union de `FREE_REACTIONS` et des packs achetés (au lieu
  d'être uniquement dérivé des achats).
- `compute_streak` bug (voir §8.1) — même fichier, changement indépendant.
- Nouveaux champs sur `GET /me` :
  - `"redCardsReceived": <int>` — `COUNT(*)` sur `red_cards` jointes à `pintes` où
    `pintes.account_id == account.id` (tous cartons rouges reçus sur toutes mes pintes, y compris
    celles déjà revalidées — compteur cumulatif, jamais décrémenté par un retrait/revalidation).
  - `"invalidatedPintesCount": <int>` — `COUNT(*) FROM pintes WHERE account_id=... AND status='invalidated'`
    (compte **actuel**, redescend si une pinte est revalidée).

## 5. Temps réel côté app

Le `CounterController` (ou équivalent qui écoute `/counter/stream`) gagne un cas :

```
case 'pinte_status':
    ref.read(feedControllerProvider.notifier).onPinteStatusChanged(id: msg['id'], invalidated: msg['invalidated']);
```

`FeedController.onPinteStatusChanged` met à jour l'item correspondant dans la liste en mémoire
(pattern déjà utilisé pour `react()` optimiste — `withReaction`), pas de re-fetch réseau.

## 6. Frontend

### 6.1 `lib/models/feed_item.dart` (modifié)

Nouveaux champs : `postedAt` (`DateTime`), `invalidated` (`bool`, défaut `false`), `myRedCard`
(`bool`, défaut `false`). `fromJson` parse `posted_at`/`invalidated`/`my_red_card`. Nouvelle méthode
`withRedCard({required bool myRedCard, required bool invalidated})` sur le même modèle que
`withReaction`.

### 6.2 `lib/data/api_client.dart` (modifié)

```dart
Future<({bool myRedCard, bool invalidated})> toggleRedCard(String pinteId) async {
  // POST /pintes/$pinteId/red_card
}
```

`FeedItem.fromJson` intègre les nouveaux champs (aucune nouvelle méthode API pour le feed lui-même,
`getFeed` existant suffit).

### 6.3 `lib/state/feed_controller.dart` (modifié)

- `toggleRedCard(pinteId)` : optimistic update (`withRedCard`) + rollback si l'appel échoue —
  même pattern que `react()`.
- `onPinteStatusChanged(id, invalidated)` : met à jour l'item en place depuis l'événement SSE
  (voir §5), sans passer par l'API client.

### 6.4 `lib/ui/widgets/feed_item_card.dart` (modifié)

- Nouveau bouton carton rouge à côté de `_LikeButton` (`🚩` ou icône `Icons.flag`, teinte rouge
  quand `myRedCard == true`) — appelle `onRedCard`, pas mêlé au `ReactionPicker` (action de
  modération, pas une réaction ludique). Masqué si `item` appartient au compte courant (comparaison
  côté UI en plus du 409 côté serveur, pour ne pas proposer une action vouée à échouer).
- Si `item.invalidated` : la photo est désaturée (`ColorFiltered` — matrice niveaux de gris) et un
  overlay centré « Invalidée » (fond sombre semi-transparent, texte blanc) recouvre l'image.
  Les boutons like/réaction/carton rouge restent fonctionnels (une pinte peut redescendre sous le
  seuil et se revalider).
- Affichage de l'heure : sous « vient de poser sa pinte », ajouter l'heure locale formatée
  (`HH:mm`) à partir de `item.postedAt`.

### 6.5 `lib/models/profile.dart` (modifié)

Nouveaux champs `redCardsReceived` (`int`, défaut 0) et `invalidatedPintesCount` (`int`, défaut 0)
sur `Profile`, parsés depuis `redCardsReceived`/`invalidatedPintesCount`.

### 6.6 `lib/ui/profile_screen.dart` (modifié)

Deux nouvelles tuiles de stat (même style que les stats existantes — pintes/streak) :
« 🚩 Cartons reçus » et « ⛔ Pintes invalidées ».

### 6.7 `lib/ui/shop_screen.dart` (modifié)

- `_packCatalog` : retirer l'entrée `starter_pack` (miroir du backend, §4.5).
- Nouveau bandeau au-dessus de la liste des packs : « 🔥⭐ Fire et Star sont gratuites dès le
  départ ! » — évite la confusion de voir disparaître un pack sans explication.

### 6.8 `lib/ui/onboarding_screen.dart` (modifié)

Remplacer le `Container` emoji 🍺 (ligne ~235-251) par `BeerGlassLogo(height: 74)` — widget déjà
existant (`lib/ui/widgets/beer_glass_logo.dart`), même taille que le conteneur actuel.

## 7. Tests

### 7.1 Backend (`back/tests/`)

- `test_moderation.py` (nouveau, unités pures) : `should_invalidate` — sous le seuil absolu, sous
  le seuil de ratio, au-dessus des deux, `views == 0`.
- `test_pintes.py` (modifié) :
  - Toggle carton rouge : pose/retrait, 409 sur sa propre pinte.
  - Poser N cartons rouges avec assez de vues simulées (insérer directement dans `views` via la
    session de test) → `status` passe à `invalidated`, `GET /counter` diminue.
  - Retirer un carton rouge sous le seuil → `status` repasse à `active`, `GET /counter` remonte.
  - `GET /feed` inclut désormais les pintes invalidées (avec `invalidated: true`), toujours
    absentes de `test_rankings.py`/streak.
- `test_shop.py` (modifié) : `starter_pack` absent du catalogue ; `GET /me` renvoie `fire`/`star`
  dans `availableReactions` pour un compte tout neuf sans aucun achat.
- `test_profile.py` (modifié) : `redCardsReceived`/`invalidatedPintesCount` sur `GET /me` ; le
  bug streak (voir §8.1) avec un test qui échouait de façon intermittente selon l'heure locale.

### 7.2 Flutter (`app/test/`)

- `feed_controller_test.dart` : `toggleRedCard` optimistic + rollback ; `onPinteStatusChanged` met
  à jour l'item ciblé sans toucher les autres.
- `models_test.dart` : parsing `posted_at`/`invalidated`/`my_red_card`, `redCardsReceived`.
- Widget `feed_item_card` : overlay « Invalidée » visible seulement si `invalidated == true` ;
  bouton carton rouge absent sur ses propres pintes.

## 8. Correctifs annexes (implémentation directe, pas de design)

### 8.1 Bug streak (`back/app/domain/streak.py`)

`dt.date.today()` utilise le fuseau **système**, pas un fuseau fixe — incohérent avec
`rankings.py` qui ancre tout sur `ZoneInfo("Europe/Paris")`. Remplacer par l'équivalent
`Europe/Paris` du jour courant.

### 8.2 Logo onboarding

Voir §6.8 — inclus ici pour traçabilité mais déjà détaillé côté frontend ci-dessus.

### 8.3 Bug de reconnexion en arrière-plan

Hors spec — traité séparément via `systematic-debugging`, pas un problème de conception.

## 9. Critères d'acceptation

1. `fire` et `star` disponibles sans achat dès la création du compte ; `starter_pack` n'apparaît
   plus dans `GET /shop/packs`.
2. Une pinte recevant ≥ 3 cartons rouges **et** ≥ 20 % de ses vues distinctes passe en
   `invalidated` : grisée + overlay dans le feed de tous les utilisateurs (temps réel), sortie du
   total `/counter`, absente des rankings/streak.
3. Retirer un carton rouge (ou l'accumulation de nouvelles vues) qui fait repasser le ratio sous
   le seuil revalide automatiquement la pinte (réintégrée au total, overlay disparaît).
4. Le profil affiche le nombre de cartons rouges reçus (cumulatif) et le nombre de pintes
   actuellement invalidées.
5. L'heure de post est visible sur chaque carte du feed.
6. Le logo animé (`BeerGlassLogo`) remplace l'emoji 🍺 sur l'écran d'onboarding.
7. `compute_streak` ne dépend plus du fuseau système.
8. `ruff check . && black .` propre, `flutter analyze` propre, suites pytest + flutter test vertes.

## 10. Fichiers touchés

**Backend (nouveaux) :** `app/domain/moderation.py`, `migrations/versions/<rev>_add_moderation.py`,
`tests/test_moderation.py`.
**Backend (modifs) :** `app/domain/counter.py`, `app/domain/streak.py`, `app/routers/feed.py`,
`app/routers/pintes.py`, `app/routers/shop.py`, `app/routers/profile.py`, `app/main.py`,
`tests/test_pintes.py`, `tests/test_shop.py`, `tests/test_profile.py`.
**Frontend (modifs) :** `lib/models/feed_item.dart`, `lib/models/profile.dart`,
`lib/data/api_client.dart`, `lib/state/feed_controller.dart`, `lib/ui/widgets/feed_item_card.dart`,
`lib/ui/profile_screen.dart`, `lib/ui/shop_screen.dart`, `lib/ui/onboarding_screen.dart`,
`test/feed_controller_test.dart`, `test/models_test.dart`.
