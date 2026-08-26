# Tchin.beer — App Flutter

Le « cœur émotionnel » côté mobile : poste une photo de pinte, vois le **compteur mondial
monter en temps réel** (SSE), parcours le **fil commun** et like, consulte ton **profil léger**.

Consomme le backend FastAPI (`../back/`) : `/auth/device`, `/counter`, `/counter/stream`,
`/pintes`, `/feed`, `/pintes/{id}/like`, `/me`.

## Prérequis

- Flutter SDK ≥ 3.4 (testé avec Flutter 3.44 / Dart 3.12), `flutter doctor` au vert.
- Un device : émulateur Android, simulateur iOS, ou device physique.
- Le backend qui tourne (voir `../back/README.md` : `docker compose up -d` + `alembic upgrade head` + `uvicorn`).

## Démarrage

```bash
flutter pub get

# Émulateur Android (10.0.2.2 = localhost de la machine hôte)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Simulateur iOS / device sur le même réseau
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

La base URL par défaut (sans `--dart-define`) est `http://10.0.2.2:8000` (cf. `lib/config.dart`).

## Build de production (Android)

L'URL de l'API de prod vit dans `dart_defines/prod.json`. Le build release est signé
avec la clé d'upload définie dans `android/key.properties` (gitignoré ; keystore hors repo).

```bash
# AAB signé pour le Play Store, branché sur l'API de prod
flutter build appbundle --release --dart-define-from-file=dart_defines/prod.json
# → build/app/outputs/bundle/release/app-release.aab
```

> Play exige un `versionCode` (le `+N` de `version:` dans `pubspec.yaml`) strictement
> supérieur au dernier build uploadé. Bumper à chaque soumission.
>
> iOS : `API_BASE_URL` est injectée par Xcode Cloud (variable d'environnement du workflow),
> cf. `ios/ci_scripts/ci_post_clone.sh`.

## Tests

Les tests utilisent `MockClient` (pas de backend requis).

```bash
flutter test
dart format . && flutter analyze   # gate qualité : 0 issue
```

- Le client SSE est testé par parsing d'un flux synthétique ; les controllers Riverpod par
  `ProviderContainer` + overrides ; un golden léger vérifie le format compteur fr-FR.
- `test/flutter_test_config.dart` désactive le fetch runtime de Google Fonts (pas de réseau en test).
- L'UI caméra (`CaptureScreen`) nécessite un device et n'est pas couverte par les tests unitaires ;
  la logique testable est isolée dans `SubmissionController`.

## Architecture

Couches à dépendance entrante uniquement :

```
lib/
  models/      # FeedItem, Profile, Session (+ fromJson)
  data/        # ApiClient (REST), SseClient, TokenStore (secure storage)
  state/       # providers Riverpod : session, counter, feed, profile, submission
  ui/          # RootGate → Onboarding | AppShell (Accueil · Fil · Profil + Capture/Succès)
  theme/       # design tokens (couleurs/typo/rayons) + thème
  util/        # formatCountFr (espaces fines fr-FR)
```

Principes : compteur **monotone** piloté SSE ; succès de pinte **jamais optimiste** (numéro réel
confirmé par le serveur) ; like **optimiste** réconcilié ; token appareil en `Bearer` persisté.

## Périmètre

Onglets **Accueil · Fil · Profil** + overlays **Capture · Succès**. L'onglet **Villes** est réservé
dans la nav mais inerte ; les cartes Fondateur / Pinte+ sont des teasers statiques. Le fil affiche
un placeholder rayé par teinte (le backend n'expose pas encore d'URL photo). Ces éléments relèvent
d'incréments ultérieurs.
