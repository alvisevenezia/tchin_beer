# Cœur émotionnel — App Flutter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire l'app Flutter du « cœur émotionnel » : onboarding appareil, compteur mondial temps réel (SSE), capture photo d'une pinte → +1 validé, fil commun avec likes, et profil léger.

**Architecture:** App Flutter mobile portrait, état **Riverpod** (Notifier/AsyncNotifier sans codegen). Couches `models` → `data` (ApiClient REST + SseClient + TokenStore) → `state` (providers) → `ui` (écrans/widgets) → `theme` (design tokens). Dépendance unique inward : `ui` lit `state`, `state` lit `data`, `data` lit `models`. Le backend FastAPI (`back/`) est déjà livré et fournit `/auth/device`, `/counter`, `/counter/stream`, `/pintes`, `/feed`, `/pintes/{id}/like`, `/me`.

**Tech Stack:** Flutter (Dart ≥ 3.4), `flutter_riverpod` ^2.5, `http` ^1.2 (REST multipart + SSE), `camera` ^0.11, `permission_handler` ^11, `flutter_secure_storage` ^9, `intl` ^0.19, `google_fonts` ^6. Tests : `flutter_test` + `http`'s `MockClient`. Qualité : `dart format` + `flutter analyze`.

## Global Constraints

- **Dart ≥ 3.4**, null-safety, `flutter analyze` sans warning et `dart format` propre avant chaque commit.
- **Toolchain non installé** : Flutter/Dart n'est pas présent sur la machine. Chaque commande `flutter`/`dart` du plan suppose le SDK installé (cf. Task 0). Tant qu'il ne l'est pas, l'exécution est bloquée (analogue au blocage Docker du backend).
- **Périmètre** : onglets **Accueil · Fil · Profil** + overlays **Capture · Succès** + onboarding. Slot **Villes** réservé dans la nav mais inerte. Cartes Fondateur/Pinte+ = teasers statiques non interactifs.
- **Auth** : `Authorization: Bearer <device_token>` sur tous les appels sauf `POST /auth/device`. Token persité via `flutter_secure_storage`.
- **Succès jamais optimiste** : l'overlay Succès n'apparaît QUE sur la réponse serveur de `POST /pintes` (numéro réel). Échec réseau → état « réessayer ».
- **Like optimiste** : ±1 immédiat, réconcilié avec la réponse `{likes, liked}`.
- **Compteur monotone** : piloté par SSE ; ne jamais reculer (ignorer un `total` inférieur au courant).
- **Tones autorisés** : `amber`, `coral`, `sky`. Le fil affiche un **placeholder rayé par teinte** (`/feed` n'expose pas d'URL photo dans cet incrément).
- **Format compteur fr-FR** : séparateurs de milliers = espaces fines insécables (` `).
- **Design tokens** (handoff) — couleurs : fond `#FFF4E0`, foam `#FFFBF2`, encre `#2A1A0D`, ambre `#F4A722`, corail `#FF6A3D`, ciel `#1AA3D6`, live `#FF3B30`, atténué `#9A865F`, rail `#ECDCBF`, onglet inactif `#B6A081`. Polices : Bricolage Grotesque (display 700/800), Hanken Grotesk (UI 400–700). Cible 390×758 portrait.
- **Connectivité dev** : base URL configurable via `--dart-define=API_BASE_URL=...`. Défaut émulateur Android `http://10.0.2.2:8000`, simu iOS `http://localhost:8000`.
- **Dépôt** : nouveau dépôt git indépendant `app/` (frère de `back/`).

---

### Task 0 (préalable, hors TDD) : Installer le toolchain Flutter

> Bloquant pour toutes les tâches suivantes. À faire par l'opérateur humain ou via un `!` en session.

- [ ] **Step 1 : Installer Flutter** — tarball officiel ou snap.

```bash
sudo snap install flutter --classic   # OU : tarball depuis https://docs.flutter.dev/get-started/install/linux
flutter --version                      # doit afficher Flutter 3.2x + Dart 3.x
flutter doctor                         # résoudre les ✗ (Android toolchain pour un run réel)
```

- [ ] **Step 2 : Vérifier qu'un device est disponible** (émulateur Android, simu iOS, ou Chrome pour smoke UI).

```bash
flutter devices
```

Expected : au moins un device listé. (Les tests `flutter test` ne nécessitent pas de device ; un run réel oui.)

---

### Task 1 : Scaffold `app/` + design tokens + smoke test

**Files:**
- Create: `app/pubspec.yaml`, `app/lib/main.dart`, `app/lib/theme/tokens.dart`, `app/lib/theme/app_theme.dart`, `app/lib/app.dart`
- Test: `app/test/smoke_test.dart`

**Interfaces:**
- Produces: `AppTokens` (constantes de couleurs/rayons/espacements), `buildAppTheme() -> ThemeData`, `PintesApp` (widget racine `ProviderScope` + `MaterialApp`).

- [ ] **Step 1 : Générer le projet + dépendances**

```bash
cd app && flutter create --org fr.pintes --project-name pintes_app .
git init
flutter pub add flutter_riverpod http camera permission_handler flutter_secure_storage intl google_fonts
flutter pub add --dev flutter_lints
```

`pubspec.yaml` doit inclure (extrait) :
```yaml
environment:
  sdk: ">=3.4.0 <4.0.0"
dependencies:
  flutter_riverpod: ^2.5.1
  http: ^1.2.2
  camera: ^0.11.0
  permission_handler: ^11.3.1
  flutter_secure_storage: ^9.2.2
  intl: ^0.19.0
  google_fonts: ^6.2.1
```

- [ ] **Step 2 : Écrire les design tokens**

```dart
// lib/theme/tokens.dart
import 'package:flutter/material.dart';

class AppTokens {
  // Couleurs (handoff)
  static const cream = Color(0xFFFFF4E0);
  static const foam = Color(0xFFFFFBF2);
  static const ink = Color(0xFF2A1A0D);
  static const amber = Color(0xFFF4A722);
  static const coral = Color(0xFFFF6A3D);
  static const sky = Color(0xFF1AA3D6);
  static const live = Color(0xFFFF3B30);
  static const muted = Color(0xFF9A865F);
  static const rail = Color(0xFFECDCBF);
  static const tabInactive = Color(0xFFB6A081);

  // Rayons
  static const radiusCard = 18.0;
  static const radiusThumb = 20.0;
  static const radiusPill = 100.0;

  // Espacements
  static const screenPadH = 24.0;
  static const gapCard = 12.0;

  // Teintes de pinte → couleur d'accent
  static Color toneColor(String tone) => switch (tone) {
        'coral' => coral,
        'sky' => sky,
        _ => amber,
      };
}
```

- [ ] **Step 3 : Écrire le thème**

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, scaffoldBackgroundColor: AppTokens.cream);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: AppTokens.coral, surface: AppTokens.foam),
    textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme)
        .apply(bodyColor: AppTokens.ink, displayColor: AppTokens.ink),
  );
}

// Style des grands chiffres / titres (Bricolage Grotesque).
TextStyle displayStyle({double size = 30, FontWeight weight = FontWeight.w800}) =>
    GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, letterSpacing: -0.02, color: AppTokens.ink);
```

- [ ] **Step 4 : Écrire le widget racine + main**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';

class PintesApp extends StatelessWidget {
  const PintesApp({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Le Million de Pintes',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: home,
      );
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(
    child: PintesApp(home: Scaffold(body: Center(child: Text('Pintes')))),
  ));
}
```

- [ ] **Step 5 : Écrire le smoke test**

```dart
// test/smoke_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/app.dart';

void main() {
  testWidgets('app boots and shows placeholder', (tester) async {
    await tester.pumpWidget(const PintesApp(home: Scaffold(body: Center(child: Text('Pintes')))));
    expect(find.text('Pintes'), findsOneWidget);
  });
}
```

- [ ] **Step 6 : Lancer le test (succès attendu)**

Run: `flutter test test/smoke_test.dart`
Expected: PASS (1 test).

- [ ] **Step 7 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "chore: scaffold Flutter app + design tokens + theme"
```

---

### Task 2 : Modèles + format compteur fr-FR

**Files:**
- Create: `app/lib/models/feed_item.dart`, `app/lib/models/profile.dart`, `app/lib/models/session.dart`, `app/lib/util/format.dart`
- Test: `app/test/format_test.dart`, `app/test/models_test.dart`

**Interfaces:**
- Produces:
  - `formatCountFr(int) -> String` (espaces fines ` `).
  - `FeedItem({String id, int number, String name, String city, String tone, int likes, bool liked})` + `FeedItem.fromJson(Map)` + `copyWith(...)`.
  - `Profile({String pseudo, String city, int myCount, int streak})` + `fromJson`.
  - `Session({String deviceToken, String pseudo, String city})` + `fromJson`.

- [ ] **Step 1 : Écrire les tests qui échouent**

```dart
// test/format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/util/format.dart';

void main() {
  test('formats thousands with thin spaces fr-FR', () {
    expect(formatCountFr(123456), '123 456');
    expect(formatCountFr(1000000), '1 000 000');
    expect(formatCountFr(7), '7');
  });
}
```

```dart
// test/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/feed_item.dart';

void main() {
  test('FeedItem.fromJson + copyWith', () {
    final i = FeedItem.fromJson({
      'id': 'a', 'number': 42, 'name': 'Léo', 'city': 'Toulouse',
      'tone': 'coral', 'likes': 3, 'liked': false,
    });
    expect(i.number, 42);
    expect(i.copyWith(liked: true, likes: 4).liked, true);
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/format_test.dart test/models_test.dart` → FAIL (imports manquants).

- [ ] **Step 3 : Implémenter le format**

```dart
// lib/util/format.dart
import 'package:intl/intl.dart';

final _fmt = NumberFormat.decimalPattern('fr_FR');

/// Total formaté avec espaces fines insécables (handoff fr-FR).
String formatCountFr(int value) =>
    _fmt.format(value).replaceAll(' ', ' ').replaceAll(' ', ' ');
```

- [ ] **Step 4 : Implémenter les modèles**

```dart
// lib/models/feed_item.dart
class FeedItem {
  const FeedItem({
    required this.id, required this.number, required this.name,
    required this.city, required this.tone, required this.likes, required this.liked,
  });
  final String id;
  final int number;
  final String name;
  final String city;
  final String tone;
  final int likes;
  final bool liked;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String,
        city: j['city'] as String,
        tone: j['tone'] as String,
        likes: j['likes'] as int,
        liked: j['liked'] as bool,
      );

  FeedItem copyWith({int? likes, bool? liked}) => FeedItem(
        id: id, number: number, name: name, city: city, tone: tone,
        likes: likes ?? this.likes, liked: liked ?? this.liked,
      );
}
```

```dart
// lib/models/profile.dart
class Profile {
  const Profile({required this.pseudo, required this.city, required this.myCount, required this.streak});
  final String pseudo;
  final String city;
  final int myCount;
  final int streak;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        pseudo: j['pseudo'] as String, city: j['city'] as String,
        myCount: j['myCount'] as int, streak: j['streak'] as int,
      );
}
```

```dart
// lib/models/session.dart
class Session {
  const Session({required this.deviceToken, required this.pseudo, required this.city});
  final String deviceToken;
  final String pseudo;
  final String city;
  factory Session.fromJson(Map<String, dynamic> j) => Session(
        deviceToken: j['device_token'] as String,
        pseudo: j['pseudo'] as String, city: j['city'] as String,
      );
}
```

- [ ] **Step 5 : Lancer (succès attendu)** — `flutter test test/format_test.dart test/models_test.dart` → PASS.

- [ ] **Step 6 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: models (feed/profile/session) + fr-FR counter format"
```

---

### Task 3 : ApiClient REST (+ TokenStore) testé avec MockClient

**Files:**
- Create: `app/lib/data/token_store.dart`, `app/lib/data/api_client.dart`, `app/lib/config.dart`
- Test: `app/test/api_client_test.dart`

**Interfaces:**
- Consumes: `FeedItem`, `Profile`, `Session`.
- Produces:
  - `abstract TokenStore { Future<String?> read(); Future<void> write(String); }` + `InMemoryTokenStore` (tests) + `SecureTokenStore` (prod).
  - `ApiClient(http.Client client, {required String baseUrl, required TokenStore tokens})` avec :
    - `Future<Session> createDevice({required String pseudo, required String city, String? deviceToken})`
    - `Future<int> getCounter()`
    - `Future<({int number, int total, FeedItem item})> postPinte({required List<int> bytes, required String filename, required String contentType, String? tone})`
    - `Future<({List<FeedItem> items, String? nextCursor})> getFeed({String? cursor, int limit})`
    - `Future<({int likes, bool liked})> toggleLike(String pinteId)`
    - `Future<Profile> getMe()`
  - Header `Authorization: Bearer <token>` ajouté automatiquement si `tokens.read()` non nul.

- [ ] **Step 1 : Écrire les tests qui échouent (MockClient)**

```dart
// test/api_client_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pintes_app/data/api_client.dart';
import 'package:pintes_app/data/token_store.dart';

ApiClient _client(MockClient mock, {String? token}) {
  final store = InMemoryTokenStore();
  if (token != null) store.write(token);
  return ApiClient(mock, baseUrl: 'http://test', tokens: store);
}

void main() {
  test('getCounter parses total', () async {
    final api = _client(MockClient((r) async {
      expect(r.url.path, '/counter');
      return http.Response(jsonEncode({'total': 17}), 200);
    }));
    expect(await api.getCounter(), 17);
  });

  test('createDevice posts pseudo/city and parses session', () async {
    final api = _client(MockClient((r) async {
      expect(r.url.path, '/auth/device');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['pseudo'], 'Léo');
      return http.Response(
        jsonEncode({'device_token': 'tok', 'pseudo': 'Léo', 'city': 'Toulouse'}), 200);
    }));
    final s = await api.createDevice(pseudo: 'Léo', city: 'Toulouse');
    expect(s.deviceToken, 'tok');
  });

  test('toggleLike sends Bearer header', () async {
    final api = _client(MockClient((r) async {
      expect(r.headers['authorization'], 'Bearer tok');
      return http.Response(jsonEncode({'likes': 1, 'liked': true}), 200);
    }), token: 'tok');
    final res = await api.toggleLike('p1');
    expect(res.liked, true);
  });

  test('getFeed parses items + next_cursor', () async {
    final api = _client(MockClient((r) async {
      return http.Response(jsonEncode({
        'items': [
          {'id': 'a', 'number': 1, 'name': 'A', 'city': 'X', 'tone': 'amber', 'likes': 0, 'liked': false}
        ],
        'next_cursor': null,
      }), 200);
    }), token: 'tok');
    final res = await api.getFeed();
    expect(res.items.single.id, 'a');
    expect(res.nextCursor, isNull);
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/api_client_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter TokenStore**

```dart
// lib/data/token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
}

class InMemoryTokenStore implements TokenStore {
  String? _t;
  @override
  Future<String?> read() async => _t;
  @override
  Future<void> write(String token) async => _t = token;
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;
  static const _key = 'device_token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
}
```

- [ ] **Step 4 : Implémenter config + ApiClient**

```dart
// lib/config.dart
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
```

```dart
// lib/data/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feed_item.dart';
import '../models/profile.dart';
import '../models/session.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String? code;
  @override
  String toString() => 'ApiException($status, $code)';
}

class ApiClient {
  ApiClient(this._client, {required this.baseUrl, required this.tokens});
  final http.Client _client;
  final String baseUrl;
  final TokenStore tokens;

  Future<Map<String, String>> _headers() async {
    final t = await tokens.read();
    return {if (t != null) 'authorization': 'Bearer $t'};
  }

  Uri _uri(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  Never _fail(http.Response r) {
    String? code;
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['detail'] is Map) code = body['detail']['code'] as String?;
    } catch (_) {}
    throw ApiException(r.statusCode, code);
  }

  Future<Session> createDevice({required String pseudo, required String city, String? deviceToken}) async {
    final r = await _client.post(_uri('/auth/device'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'pseudo': pseudo, 'city': city, if (deviceToken != null) 'device_token': deviceToken}));
    if (r.statusCode != 200) _fail(r);
    return Session.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<int> getCounter() async {
    final r = await _client.get(_uri('/counter'), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['total'] as int;
  }

  Future<({int number, int total, FeedItem item})> postPinte({
    required List<int> bytes, required String filename, required String contentType, String? tone,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/pintes'))
      ..headers.addAll(await _headers())
      ..files.add(http.MultipartFile.fromBytes('photo', bytes,
          filename: filename, contentType: _mediaType(contentType)));
    if (tone != null) req.fields['tone'] = tone;
    final r = await http.Response.fromStream(await _client.send(req));
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (number: j['number'] as int, total: j['total'] as int,
        item: FeedItem.fromJson(j['item'] as Map<String, dynamic>));
  }

  Future<({List<FeedItem> items, String? nextCursor})> getFeed({String? cursor, int limit = 20}) async {
    final r = await _client.get(
        _uri('/feed', {if (cursor != null) 'cursor': cursor, 'limit': limit}), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (
      items: (j['items'] as List).map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList(),
      nextCursor: j['next_cursor'] as String?,
    );
  }

  Future<({int likes, bool liked})> toggleLike(String pinteId) async {
    final r = await _client.post(_uri('/pintes/$pinteId/like'), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (likes: j['likes'] as int, liked: j['liked'] as bool);
  }

  Future<Profile> getMe() async {
    final r = await _client.get(_uri('/me'), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    return Profile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}

// MediaType depuis le content-type "image/jpeg".
http.MultipartFile _unused() => throw UnimplementedError();
```

> Note : `MultipartFile.fromBytes` attend un `MediaType` de `package:http_parser`. Ajouter l'import et le helper :

```dart
// en tête de api_client.dart
import 'package:http_parser/http_parser.dart';
// ... et remplacer _mediaType :
MediaType _mediaType(String contentType) {
  final parts = contentType.split('/');
  return MediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream');
}
```
(`http_parser` est une dépendance transitive de `http` ; l'ajouter explicitement : `flutter pub add http_parser`. Supprimer le stub `_unused`.)

- [ ] **Step 5 : Lancer (succès attendu)** — `flutter test test/api_client_test.dart` → PASS (4 tests).

- [ ] **Step 6 : Analyze + format + commit**

```bash
flutter pub add http_parser && dart format . && flutter analyze
git add -A && git commit -m "feat: REST ApiClient + TokenStore (MockClient-tested)"
```

---

### Task 4 : Session bootstrap + écran Onboarding

**Files:**
- Create: `app/lib/state/providers.dart`, `app/lib/state/session_controller.dart`, `app/lib/ui/onboarding_screen.dart`
- Test: `app/test/session_controller_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TokenStore`, `Session`.
- Produces:
  - Providers globaux : `tokenStoreProvider`, `httpClientProvider`, `apiClientProvider`.
  - `sealed class SessionState { Unknown | NeedsOnboarding | Authenticated(Profile-ish pseudo/city) }`.
  - `SessionController extends AsyncNotifier<SessionState>` : `build()` lit le token (si présent → `Authenticated`, sinon `NeedsOnboarding`) ; `signUp({pseudo, city})` appelle `createDevice`, écrit le token, passe `Authenticated`.
  - `sessionControllerProvider`.

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
// test/session_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/session_controller.dart';

ProviderContainer _container(MockClient mock, TokenStore store) => ProviderContainer(overrides: [
      httpClientProvider.overrideWithValue(mock),
      tokenStoreProvider.overrideWithValue(store),
    ]);

void main() {
  test('no token -> NeedsOnboarding', () async {
    final c = _container(MockClient((_) async => http.Response('{}', 200)), InMemoryTokenStore());
    final s = await c.read(sessionControllerProvider.future);
    expect(s, isA<NeedsOnboarding>());
  });

  test('signUp stores token and becomes Authenticated', () async {
    final store = InMemoryTokenStore();
    final c = _container(MockClient((r) async => http.Response(
        jsonEncode({'device_token': 'tok', 'pseudo': 'Léo', 'city': 'Toulouse'}), 200)), store);
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).signUp(pseudo: 'Léo', city: 'Toulouse');
    expect(await store.read(), 'tok');
    expect(c.read(sessionControllerProvider).value, isA<Authenticated>());
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/session_controller_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter les providers de base**

```dart
// lib/state/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../data/api_client.dart';
import '../data/token_store.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      ref.watch(httpClientProvider),
      baseUrl: apiBaseUrl,
      tokens: ref.watch(tokenStoreProvider),
    ));
```

- [ ] **Step 4 : Implémenter le SessionController**

```dart
// lib/state/session_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

sealed class SessionState {
  const SessionState();
}
class NeedsOnboarding extends SessionState {
  const NeedsOnboarding();
}
class Authenticated extends SessionState {
  const Authenticated(this.pseudo, this.city);
  final String pseudo;
  final String city;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final token = await ref.watch(tokenStoreProvider).read();
    if (token == null) return const NeedsOnboarding();
    // Token présent : valider en chargeant le profil.
    final me = await ref.watch(apiClientProvider).getMe();
    return Authenticated(me.pseudo, me.city);
  }

  Future<void> signUp({required String pseudo, required String city}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final session = await api.createDevice(pseudo: pseudo, city: city);
      await ref.read(tokenStoreProvider).write(session.deviceToken);
      return Authenticated(session.pseudo, session.city);
    });
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);
```

- [ ] **Step 5 : Implémenter l'écran Onboarding**

```dart
// lib/ui/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../state/session_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pseudo = TextEditingController();
  final _city = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.screenPadH),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 40),
            Text('Le Million\nde Pintes', style: displayStyle(size: 36)),
            const SizedBox(height: 24),
            TextField(controller: _pseudo, decoration: const InputDecoration(labelText: 'Ton pseudo')),
            const SizedBox(height: 12),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ta ville')),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTokens.coral),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? '...' : 'Rejoindre le mouvement'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_pseudo.text.trim().isEmpty || _city.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await ref.read(sessionControllerProvider.notifier)
        .signUp(pseudo: _pseudo.text.trim(), city: _city.text.trim());
    if (mounted) setState(() => _busy = false);
  }
}
```

- [ ] **Step 6 : Lancer (succès attendu)** — `flutter test test/session_controller_test.dart` → PASS (2 tests).

- [ ] **Step 7 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: session bootstrap + onboarding (device signup)"
```

---

### Task 5 : Client SSE + provider compteur + section Accueil

**Files:**
- Create: `app/lib/data/sse_client.dart`, `app/lib/state/counter_controller.dart`, `app/lib/ui/home_screen.dart`
- Modify: `app/lib/state/providers.dart` (ajout `sseClientProvider`)
- Test: `app/test/sse_client_test.dart`, `app/test/counter_controller_test.dart`

**Interfaces:**
- Consumes: `ApiClient.getCounter`, base URL, token.
- Produces:
  - `class SseEvent { String? event; String data; }`
  - `Stream<SseEvent> parseSse(Stream<List<int>> bytes)` — découpe les lignes, agrège `event:`/`data:`, émet sur ligne vide.
  - `SseClient` : `Stream<SseEvent> connect(String path)` (GET streamé avec Bearer + `Accept: text/event-stream`).
  - `CounterState({int total, bool reconnecting})`.
  - `CounterController extends Notifier<CounterState>` : initial via `getCounter`, applique les events `counter` (monotone), et `feed_item` relayés vers `feedControllerProvider.prepend`. `bumpFromFeed(int total)`.
  - `counterControllerProvider`.

- [ ] **Step 1 : Écrire le test du parseur SSE (échec attendu)**

```dart
// test/sse_client_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/data/sse_client.dart';

void main() {
  test('parseSse aggregates event + data on blank line', () async {
    final raw = 'event: counter\n'
        'data: {"type":"counter","total":5}\n'
        '\n'
        'data: {"type":"feed_item"}\n'
        '\n';
    final events = await parseSse(Stream.value(utf8.encode(raw))).toList();
    expect(events.length, 2);
    expect(events[0].event, 'counter');
    expect(events[0].data, '{"type":"counter","total":5}');
    expect(events[1].event, isNull);
  });

  test('parseSse ignores comment keep-alive lines', () async {
    final raw = ': ping\n\ndata: {"type":"counter","total":9}\n\n';
    final events = await parseSse(Stream.value(utf8.encode(raw))).toList();
    expect(events.single.data, '{"type":"counter","total":9}');
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/sse_client_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter le parseur + client SSE**

```dart
// lib/data/sse_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

class SseEvent {
  SseEvent(this.event, this.data);
  final String? event;
  final String data;
}

/// Parse un flux d'octets text/event-stream en SseEvent (RFC sous-ensemble).
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? event;
  final data = StringBuffer();
  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield SseEvent(event, data.toString());
      }
      event = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // keep-alive
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(line.substring(5).trim());
    }
  }
}

class SseClient {
  SseClient(this._client, {required this.baseUrl, required this.tokens});
  final http.Client _client;
  final String baseUrl;
  final TokenStore tokens;

  Stream<SseEvent> connect(String path) async* {
    final token = await tokens.read();
    final req = http.Request('GET', Uri.parse('$baseUrl$path'))
      ..headers['accept'] = 'text/event-stream'
      ..headers['cache-control'] = 'no-cache';
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    final resp = await _client.send(req);
    yield* parseSse(resp.stream);
  }
}
```

- [ ] **Step 4 : Lancer le parseur (succès)** — `flutter test test/sse_client_test.dart` → PASS.

- [ ] **Step 5 : Écrire le test du CounterController (échec attendu)**

```dart
// test/counter_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintes_app/state/counter_controller.dart';

void main() {
  test('counter is monotonic — ignores lower totals', () {
    final c = ProviderContainer();
    final ctrl = c.read(counterControllerProvider.notifier);
    ctrl.applyTotal(10);
    expect(c.read(counterControllerProvider).total, 10);
    ctrl.applyTotal(8); // recul ignoré
    expect(c.read(counterControllerProvider).total, 10);
    ctrl.applyTotal(11);
    expect(c.read(counterControllerProvider).total, 11);
  });
}
```

- [ ] **Step 6 : Implémenter le CounterController (+ provider SSE)**

Ajouter dans `lib/state/providers.dart` :
```dart
import '../data/sse_client.dart';

final sseClientProvider = Provider<SseClient>((ref) => SseClient(
      ref.watch(httpClientProvider), baseUrl: apiBaseUrl, tokens: ref.watch(tokenStoreProvider)));
```

```dart
// lib/state/counter_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'feed_controller.dart';

class CounterState {
  const CounterState({this.total = 0, this.reconnecting = false});
  final int total;
  final bool reconnecting;
  CounterState copyWith({int? total, bool? reconnecting}) =>
      CounterState(total: total ?? this.total, reconnecting: reconnecting ?? this.reconnecting);
}

class CounterController extends Notifier<CounterState> {
  StreamSubscription? _sub;

  @override
  CounterState build() {
    ref.onDispose(() => _sub?.cancel());
    return const CounterState();
  }

  /// Total monotone : ignore tout recul.
  void applyTotal(int total) {
    if (total > state.total) state = state.copyWith(total: total, reconnecting: false);
  }

  Future<void> start() async {
    final api = ref.read(apiClientProvider);
    try {
      applyTotal(await api.getCounter());
    } catch (_) {}
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = ref.read(sseClientProvider).connect('/counter/stream').listen(
      (e) {
        final j = jsonDecode(e.data) as Map<String, dynamic>;
        switch (j['type']) {
          case 'counter':
            applyTotal(j['total'] as int);
          case 'feed_item':
            ref.read(feedControllerProvider.notifier).prepend(j['item'] as Map<String, dynamic>);
        }
      },
      onError: (_) => _reconnect(),
      onDone: _reconnect,
    );
  }

  void _reconnect() {
    state = state.copyWith(reconnecting: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (ref.mounted) _restart();
    });
  }

  Future<void> _restart() async {
    final api = ref.read(apiClientProvider);
    try {
      applyTotal(await api.getCounter());
    } catch (_) {}
    _listen();
  }
}

final counterControllerProvider =
    NotifierProvider<CounterController, CounterState>(CounterController.new);
```

> Note : `feedControllerProvider` / `prepend` proviennent de Task 6. Si Task 6 n'est pas encore implémentée par le worker, créer d'abord un stub minimal `feed_controller.dart` exposant `prepend(Map)` — mais l'ordre normal d'exécution fait Task 6 avant l'usage runtime. Le test du compteur (Step 5) ne touche pas au feed.

- [ ] **Step 7 : Implémenter la section compteur de l'écran Accueil**

```dart
// lib/ui/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import '../state/counter_controller.dart';
import '../state/profile_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onAddPinte});
  final VoidCallback onAddPinte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.screenPadH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _LiveDot(active: !counter.reconnecting),
            const SizedBox(width: 8),
            Text(counter.reconnecting ? 'RECONNEXION…' : 'EN DIRECT',
                style: const TextStyle(color: AppTokens.coral, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 6),
          const Text('Pintes bues par la communauté', style: TextStyle(color: AppTokens.muted)),
          const SizedBox(height: 8),
          Text(formatCountFr(counter.total), style: displayStyle(size: 66)),
          const Text('/ 1 000 000 — l\'objectif',
              style: TextStyle(color: Color(0xFFB89A6E), fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _Progress(value: counter.total / 1000000),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatCard(value: '${profile.valueOrNull?.myCount ?? 0}', label: 'tes pintes', color: AppTokens.amber)),
            const SizedBox(width: AppTokens.gapCard),
            Expanded(child: _StatCard(value: '${profile.valueOrNull?.streak ?? 0} 🔥', label: 'jours d\'affilée', color: AppTokens.coral)),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.coral, minimumSize: const Size.fromHeight(56)),
            onPressed: onAddPinte,
            child: const Text('🍺 Ajoute ta pinte'),
          ),
          const Center(child: Padding(padding: EdgeInsets.only(top: 8), child: Text('+1 vers le million', style: TextStyle(color: AppTokens.muted)))),
        ]),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
      width: 11, height: 11,
      decoration: BoxDecoration(color: active ? AppTokens.live : AppTokens.muted, shape: BoxShape.circle));
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
          value: value.clamp(0, 1), minHeight: 16, backgroundColor: AppTokens.rail, color: AppTokens.coral));
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTokens.foam, borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: displayStyle(size: 26).copyWith(color: color)),
        Text(label, style: const TextStyle(color: AppTokens.muted)),
      ]));
}
```

> `profileControllerProvider` vient de Task 8 ; l'Accueil le lit en lecture seule avec fallback `0`, donc il fonctionne même avant chargement.

- [ ] **Step 8 : Lancer (succès attendu)** — `flutter test test/counter_controller_test.dart` → PASS.

- [ ] **Step 9 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: SSE client + monotonic counter + Accueil counter section"
```

---

### Task 6 : Provider Fil + écran Fil + like optimiste

**Files:**
- Create: `app/lib/state/feed_controller.dart`, `app/lib/ui/feed_screen.dart`, `app/lib/ui/widgets/feed_item_card.dart`
- Test: `app/test/feed_controller_test.dart`

**Interfaces:**
- Consumes: `ApiClient.getFeed`, `ApiClient.toggleLike`, `FeedItem`.
- Produces:
  - `FeedState({List<FeedItem> items, String? cursor, bool loading, bool hasMore, Object? error})`.
  - `FeedController extends AsyncNotifier<FeedState>` : `build()` charge la 1ʳᵉ page ; `refresh()` ; `loadMore()` ; `prepend(Map json)` (insère en tête, dédupe par `id`) ; `toggleLike(String id)` (optimiste + réconciliation).
  - `feedControllerProvider`.

- [ ] **Step 1 : Écrire le test (échec attendu)**

```dart
// test/feed_controller_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/feed_controller.dart';

Map<String, dynamic> _item(String id, {int likes = 0, bool liked = false}) =>
    {'id': id, 'number': 1, 'name': 'A', 'city': 'X', 'tone': 'amber', 'likes': likes, 'liked': liked};

void main() {
  test('optimistic like flips immediately then reconciles', () async {
    final c = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
      httpClientProvider.overrideWithValue(MockClient((r) async {
        if (r.url.path == '/feed') {
          return http.Response(jsonEncode({'items': [_item('p1')], 'next_cursor': null}), 200);
        }
        return http.Response(jsonEncode({'likes': 1, 'liked': true}), 200); // /like
      })),
    ]);
    await c.read(feedControllerProvider.future);
    final notifier = c.read(feedControllerProvider.notifier);
    final fut = notifier.toggleLike('p1');
    // Optimiste : déjà liké avant la résolution réseau.
    expect(c.read(feedControllerProvider).value!.items.single.liked, true);
    await fut;
    expect(c.read(feedControllerProvider).value!.items.single.likes, 1);
  });

  test('prepend inserts new item at head and dedupes', () async {
    final c = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
      httpClientProvider.overrideWithValue(MockClient((r) async =>
          http.Response(jsonEncode({'items': [_item('p1')], 'next_cursor': null}), 200))),
    ]);
    await c.read(feedControllerProvider.future);
    c.read(feedControllerProvider.notifier).prepend(_item('p2'));
    c.read(feedControllerProvider.notifier).prepend(_item('p2')); // dup ignoré
    final ids = c.read(feedControllerProvider).value!.items.map((e) => e.id).toList();
    expect(ids, ['p2', 'p1']);
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/feed_controller_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter le FeedController**

```dart
// lib/state/feed_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import 'providers.dart';

class FeedState {
  const FeedState({this.items = const [], this.cursor, this.hasMore = true});
  final List<FeedItem> items;
  final String? cursor;
  final bool hasMore;
  FeedState copyWith({List<FeedItem>? items, String? cursor, bool? hasMore}) =>
      FeedState(items: items ?? this.items, cursor: cursor, hasMore: hasMore ?? this.hasMore);
}

class FeedController extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final page = await ref.read(apiClientProvider).getFeed();
    return FeedState(items: page.items, cursor: page.nextCursor, hasMore: page.nextCursor != null);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.cursor == null) return;
    final page = await ref.read(apiClientProvider).getFeed(cursor: cur.cursor);
    state = AsyncData(cur.copyWith(
      items: [...cur.items, ...page.items],
      cursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    ));
  }

  void prepend(Map<String, dynamic> json) {
    final item = FeedItem.fromJson(json);
    final cur = state.valueOrNull ?? const FeedState();
    if (cur.items.any((e) => e.id == item.id)) return; // dédupe
    state = AsyncData(cur.copyWith(items: [item, ...cur.items]));
  }

  Future<void> toggleLike(String id) async {
    final cur = state.valueOrNull;
    if (cur == null) return;
    // Optimiste : flip immédiat.
    final optimistic = cur.items.map((e) => e.id == id
        ? e.copyWith(liked: !e.liked, likes: e.likes + (e.liked ? -1 : 1))
        : e).toList();
    state = AsyncData(cur.copyWith(items: optimistic));
    try {
      final res = await ref.read(apiClientProvider).toggleLike(id);
      final reconciled = state.value!.items.map((e) =>
          e.id == id ? e.copyWith(liked: res.liked, likes: res.likes) : e).toList();
      state = AsyncData(state.value!.copyWith(items: reconciled));
    } catch (_) {
      state = AsyncData(cur); // rollback
    }
  }
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);
```

- [ ] **Step 4 : Lancer (succès attendu)** — `flutter test test/feed_controller_test.dart` → PASS.

- [ ] **Step 5 : Implémenter la carte d'item + l'écran Fil**

```dart
// lib/ui/widgets/feed_item_card.dart
import 'package:flutter/material.dart';
import '../../models/feed_item.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class FeedItemCard extends StatelessWidget {
  const FeedItemCard({super.key, required this.item, required this.onLike});
  final FeedItem item;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.toneColor(item.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusThumb),
              color: accent.withValues(alpha: 0.18),
            ),
            child: Stack(children: [
              Positioned(left: 10, top: 10, child: _Chip('📍 ${item.city}')),
              Positioned(left: 10, bottom: 10, child: _Chip('#${item.number}')),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          CircleAvatar(radius: 19, backgroundColor: accent, child: Text(item.name.characters.first, style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Text('vient de poser sa pinte', style: TextStyle(color: AppTokens.muted, fontSize: 13)),
          ])),
          _LikeButton(item: item, onLike: onLike),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xC72A1206), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: const TextStyle(color: Color(0xFFFFE3C2), fontWeight: FontWeight.w700)));
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.item, required this.onLike});
  final FeedItem item;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.toneColor(item.tone);
    return GestureDetector(
      onTap: onLike,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: item.liked ? accent : AppTokens.foam,
          border: Border.all(color: AppTokens.rail),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('♥ ${item.likes}',
            style: TextStyle(color: item.liked ? Colors.white : AppTokens.muted, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
```

```dart
// lib/ui/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../state/feed_controller.dart';
import 'widgets/feed_item_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.screenPadH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Text('Le fil', style: displayStyle(size: 30)),
          const SizedBox(height: 12),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (state) => state.items.isEmpty
                  ? const Center(child: Text('Aucune pinte pour l\'instant.'))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
                      child: ListView.builder(
                        itemCount: state.items.length,
                        itemBuilder: (_, i) => FeedItemCard(
                          item: state.items[i],
                          onLike: () => ref.read(feedControllerProvider.notifier).toggleLike(state.items[i].id),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 6 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: feed provider (pagination/prepend) + Fil screen + optimistic like"
```

---

### Task 7 : Soumission de pinte + overlay Capture (camera) + overlay Succès

**Files:**
- Create: `app/lib/state/submission_controller.dart`, `app/lib/ui/capture_screen.dart`, `app/lib/ui/success_screen.dart`
- Test: `app/test/submission_controller_test.dart`

**Interfaces:**
- Consumes: `ApiClient.postPinte`, `CounterController.applyTotal`, `FeedController.prepend`, `ProfileController.bumpMyCount`.
- Produces:
  - `sealed SubmissionState { Idle | Submitting | Success(int number, int total, FeedItem item) | Failed(Object error) }`.
  - `SubmissionController extends Notifier<SubmissionState>` : `submit({bytes, filename, contentType, tone?})` → `Submitting` → sur succès applique compteur/feed/profil et passe `Success` ; sur échec `Failed` (jamais `Success`). `reset()`.
  - `submissionControllerProvider`.
  - `CaptureScreen` (viseur `camera`) et `SuccessScreen` (animation `pop`).

- [ ] **Step 1 : Écrire le test de la machine à états (échec attendu)**

```dart
// test/submission_controller_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/submission_controller.dart';

ProviderContainer _c(MockClient mock) => ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
      httpClientProvider.overrideWithValue(mock),
    ]);

void main() {
  test('successful submit ends in Success with real number', () async {
    final c = _c(MockClient((r) async => http.Response(
        jsonEncode({'number': 51, 'total': 51,
          'item': {'id': 'p', 'number': 51, 'name': 'Toi', 'city': 'Lyon', 'tone': 'coral', 'likes': 0, 'liked': false}}),
        200)));
    final ctrl = c.read(submissionControllerProvider.notifier);
    await ctrl.submit(bytes: [1, 2, 3], filename: 'p.jpg', contentType: 'image/jpeg');
    final s = c.read(submissionControllerProvider);
    expect(s, isA<Success>());
    expect((s as Success).number, 51);
  });

  test('network failure ends in Failed, never Success', () async {
    final c = _c(MockClient((r) async => http.Response('{"detail":{"code":"RATE_LIMITED"}}', 409)));
    final ctrl = c.read(submissionControllerProvider.notifier);
    await ctrl.submit(bytes: [1], filename: 'p.jpg', contentType: 'image/jpeg');
    expect(c.read(submissionControllerProvider), isA<Failed>());
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/submission_controller_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter le SubmissionController**

```dart
// lib/state/submission_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import 'providers.dart';
import 'counter_controller.dart';
import 'feed_controller.dart';
import 'profile_controller.dart';

sealed class SubmissionState {
  const SubmissionState();
}
class Idle extends SubmissionState {
  const Idle();
}
class Submitting extends SubmissionState {
  const Submitting();
}
class Success extends SubmissionState {
  const Success(this.number, this.total, this.item);
  final int number;
  final int total;
  final FeedItem item;
}
class Failed extends SubmissionState {
  const Failed(this.error);
  final Object error;
}

class SubmissionController extends Notifier<SubmissionState> {
  @override
  SubmissionState build() => const Idle();

  Future<void> submit({
    required List<int> bytes, required String filename, required String contentType, String? tone,
  }) async {
    state = const Submitting();
    try {
      final res = await ref.read(apiClientProvider)
          .postPinte(bytes: bytes, filename: filename, contentType: contentType, tone: tone);
      // Réponse serveur confirmée : appliquer aux autres états.
      ref.read(counterControllerProvider.notifier).applyTotal(res.total);
      ref.read(feedControllerProvider.notifier).prepend({
        'id': res.item.id, 'number': res.item.number, 'name': res.item.name,
        'city': res.item.city, 'tone': res.item.tone, 'likes': res.item.likes, 'liked': res.item.liked,
      });
      ref.read(profileControllerProvider.notifier).bumpMyCount();
      state = Success(res.number, res.total, res.item);
    } catch (e) {
      state = Failed(e); // jamais Success sur échec
    }
  }

  void reset() => state = const Idle();
}

final submissionControllerProvider =
    NotifierProvider<SubmissionController, SubmissionState>(SubmissionController.new);
```

- [ ] **Step 4 : Lancer (succès attendu)** — `flutter test test/submission_controller_test.dart` → PASS (2 tests).

- [ ] **Step 5 : Implémenter l'overlay Succès**

```dart
// lib/ui/success_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.number, required this.onSeeFeed, required this.onContinue});
  final int number;
  final VoidCallback onSeeFeed;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.4), colors: [Color(0xFFFFD9A0), Color(0xFFFF8C4D)]),
        ),
        child: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🍺', style: TextStyle(fontSize: 88)),
              Text('+1', style: displayStyle(size: 62)),
              const SizedBox(height: 8),
              Text('Pinte n° ${formatCountFr(number)} validée !', style: displayStyle(size: 24)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text('Le compteur grimpe, et ta ville gagne +1.', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF241308)),
                onPressed: onSeeFeed,
                child: const Text('Voir le fil', style: TextStyle(color: Color(0xFFFFCB6B))),
              ),
              TextButton(onPressed: onContinue, child: const Text('Continuer')),
            ]),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6 : Implémenter l'overlay Capture (camera)**

```dart
// lib/ui/capture_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../state/submission_controller.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, required this.onSuccess});
  final void Function(int number) onSuccess;
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _cam;
  String? _permError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _permError = 'Permission caméra refusée');
      return;
    }
    final cams = await availableCameras();
    final ctrl = CameraController(cams.first, ResolutionPreset.medium, enableAudio: false);
    await ctrl.initialize();
    if (mounted) setState(() => _cam = ctrl);
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() => _busy = true);
    final shot = await cam.takePicture();
    final bytes = await shot.readAsBytes();
    await ref.read(submissionControllerProvider.notifier)
        .submit(bytes: bytes, filename: shot.name, contentType: 'image/jpeg');
    final state = ref.read(submissionControllerProvider);
    if (!mounted) return;
    if (state is Success) {
      widget.onSuccess(state.number);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'envoi — réessaie.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14110D),
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop()),
          ),
          const Text('NOUVELLE PINTE',
              style: TextStyle(color: Color(0xFFFFCB6B), letterSpacing: 2, fontWeight: FontWeight.w700)),
          Expanded(
            child: Center(
              child: _permError != null
                  ? _PermError(message: _permError!)
                  : _cam == null
                      ? const CircularProgressIndicator()
                      : AspectRatio(aspectRatio: _cam!.value.aspectRatio, child: CameraPreview(_cam!)),
            ),
          ),
          const Text('Cadre ta pinte, puis appuie pour la valider.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _cam == null ? null : _shoot,
            child: Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: _busy ? Colors.white54 : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _PermError extends StatelessWidget {
  const _PermError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: Colors.white)),
        TextButton(onPressed: openAppSettings, child: const Text('Ouvrir les réglages')),
      ]);
}
```

> **Permissions natives** : ajouter `NSCameraUsageDescription` dans `ios/Runner/Info.plist` et `<uses-permission android:name="android.permission.CAMERA"/>` dans `android/app/src/main/AndroidManifest.xml`. La `CaptureScreen` n'est pas couverte par les tests unitaires (caméra = device requis) ; vérification manuelle/intégration sur device. La logique testable est isolée dans `SubmissionController` (Step 1).

- [ ] **Step 7 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: pinte submission state machine + Capture (camera) + Success overlays"
```

---

### Task 8 : Provider profil + écran Profil + shell de navigation

**Files:**
- Create: `app/lib/state/profile_controller.dart`, `app/lib/ui/profile_screen.dart`, `app/lib/ui/app_shell.dart`
- Test: `app/test/profile_controller_test.dart`, `app/test/app_shell_test.dart`

**Interfaces:**
- Consumes: `ApiClient.getMe`, `Profile`, tous les écrans (Home/Feed/Profile/Capture/Success).
- Produces:
  - `ProfileController extends AsyncNotifier<Profile>` : `build()` charge `/me` ; `bumpMyCount()` (incrément local optimiste après une pinte).
  - `profileControllerProvider`.
  - `AppShell` : `Scaffold` avec `IndexedStack` (Accueil/Fil/Profil), `BottomNavigationBar` 5 slots (Accueil · Fil · **(+)** · Villes(inerte) · Profil), bouton **+** central corail surélevé → push `CaptureScreen` ; à la réussite, push `SuccessScreen`.

- [ ] **Step 1 : Écrire les tests (échec attendu)**

```dart
// test/profile_controller_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/state/profile_controller.dart';

void main() {
  test('loads /me then bumpMyCount increments locally', () async {
    final c = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
      httpClientProvider.overrideWithValue(MockClient((r) async => http.Response(
          jsonEncode({'pseudo': 'Léo', 'city': 'Toulouse', 'myCount': 2, 'streak': 3}), 200))),
    ]);
    final p = await c.read(profileControllerProvider.future);
    expect(p.myCount, 2);
    c.read(profileControllerProvider.notifier).bumpMyCount();
    expect(c.read(profileControllerProvider).value!.myCount, 3);
  });
}
```

```dart
// test/app_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pintes_app/data/token_store.dart';
import 'package:pintes_app/state/providers.dart';
import 'package:pintes_app/ui/app_shell.dart';

void main() {
  testWidgets('tapping Fil tab shows the feed header', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()..write('t')),
        httpClientProvider.overrideWithValue(MockClient((r) async {
          if (r.url.path == '/me') {
            return http.Response(jsonEncode({'pseudo': 'A', 'city': 'X', 'myCount': 0, 'streak': 0}), 200);
          }
          return http.Response(jsonEncode({'items': [], 'next_cursor': null}), 200);
        })),
      ],
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pump(); // laisse les providers se résoudre
    await tester.tap(find.text('Fil'));
    await tester.pumpAndSettle();
    expect(find.text('Le fil'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer (échec attendu)** — `flutter test test/profile_controller_test.dart test/app_shell_test.dart` → FAIL.

- [ ] **Step 3 : Implémenter le ProfileController**

```dart
// lib/state/profile_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import 'providers.dart';

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() => ref.read(apiClientProvider).getMe();

  void bumpMyCount() {
    final p = state.valueOrNull;
    if (p == null) return;
    state = AsyncData(Profile(pseudo: p.pseudo, city: p.city, myCount: p.myCount + 1, streak: p.streak));
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, Profile>(ProfileController.new);
```

- [ ] **Step 4 : Implémenter l'écran Profil**

```dart
// lib/ui/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../state/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    return SafeArea(
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.screenPadH),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CircleAvatar(radius: 37, backgroundColor: AppTokens.coral,
                child: Text(p.pseudo.characters.first, style: const TextStyle(color: Colors.white, fontSize: 28))),
            const SizedBox(height: 12),
            Text(p.pseudo, style: displayStyle(size: 26)),
            Text('📍 ${p.city}', style: const TextStyle(color: AppTokens.muted)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _Stat('${p.myCount}', 'pintes'),
              _Stat('${p.streak}', 'jours'),
              const _Stat('—', 'rang ville'), // Villes hors périmètre
            ]),
            const SizedBox(height: 24),
            const _TeaserCard(title: 'Membre Fondateur', subtitle: 'Badge numéroté · réservé aux OG', color: Color(0xFF241308)),
            const SizedBox(height: 12),
            const _TeaserCard(title: 'Passer à Pinte+', subtitle: '2,99 €/mois · stats, badges, avatar', color: AppTokens.amber),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: displayStyle(size: 26)),
        Text(label, style: const TextStyle(color: AppTokens.muted)),
      ]);
}

class _TeaserCard extends StatelessWidget {
  const _TeaserCard({required this.title, required this.subtitle, required this.color});
  final String title, subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFFFFE3C2), fontWeight: FontWeight.w800, fontSize: 18)),
        Text(subtitle, style: const TextStyle(color: Color(0xFFFFCB6B))),
      ]));
}
```

- [ ] **Step 5 : Implémenter le shell de navigation**

```dart
// lib/ui/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import 'home_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'capture_screen.dart';
import 'success_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  Future<void> _openCapture() async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CaptureScreen(onSuccess: (number) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SuccessScreen(
            number: number,
            onSeeFeed: () { Navigator.of(context).pop(); setState(() => _index = 1); },
            onContinue: () => Navigator.of(context).pop(),
          ),
        ));
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        HomeScreen(onAddPinte: _openCapture),
        const FeedScreen(),
        const ProfileScreen(),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTokens.coral,
        onPressed: _openCapture,
        child: const Text('+', style: TextStyle(fontSize: 28, color: Colors.white)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index <= 1 ? _index : (_index == 2 ? 4 : _index),
        onTap: (i) {
          if (i == 2) return; // slot central FAB
          if (i == 3) return; // Villes inerte (hors périmètre)
          setState(() => _index = i == 4 ? 2 : i);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTokens.coral,
        unselectedItemColor: AppTokens.tabInactive,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'Fil'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Villes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6 : Lancer (succès attendu)** — `flutter test test/profile_controller_test.dart test/app_shell_test.dart` → PASS.

- [ ] **Step 7 : Analyze + format + commit**

```bash
dart format . && flutter analyze
git add -A && git commit -m "feat: profile provider + Profil screen + nav shell (tabs + central +)"
```

---

### Task 9 : Câblage racine (session gate + démarrage compteur) + golden fr-FR + README

**Files:**
- Modify: `app/lib/main.dart`, `app/lib/app.dart`
- Create: `app/lib/ui/root_gate.dart`, `app/test/counter_golden_test.dart`, `app/README.md`

**Interfaces:**
- Consumes: `sessionControllerProvider`, `counterControllerProvider.start`, `OnboardingScreen`, `AppShell`.
- Produces: `RootGate` qui affiche Onboarding ou AppShell selon `SessionState`, et démarre le flux SSE compteur une fois authentifié.

- [ ] **Step 1 : Écrire le golden du compteur (échec attendu)**

```dart
// test/counter_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/theme/app_theme.dart';
import 'package:pintes_app/util/format.dart';

void main() {
  testWidgets('counter renders fr-FR thin-space formatting (golden)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF4E0),
        body: Center(child: Text(formatCountFr(123456), style: displayStyle(size: 66))),
      ),
    ));
    await expectLater(find.byType(Text), matchesGoldenFile('goldens/counter_123456.png'));
  });
}
```

- [ ] **Step 2 : Générer le golden de référence**

Run: `flutter test --update-goldens test/counter_golden_test.dart`
Expected: crée `test/goldens/counter_123456.png`. Vérifier visuellement (espaces fines `123 456`).

- [ ] **Step 3 : Implémenter le RootGate**

```dart
// lib/ui/root_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_controller.dart';
import '../state/counter_controller.dart';
import 'onboarding_screen.dart';
import 'app_shell.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (s) => switch (s) {
        NeedsOnboarding() => const OnboardingScreen(),
        Authenticated() => const _AuthedApp(),
      },
    );
  }
}

class _AuthedApp extends ConsumerStatefulWidget {
  const _AuthedApp();
  @override
  ConsumerState<_AuthedApp> createState() => _AuthedAppState();
}

class _AuthedAppState extends ConsumerState<_AuthedApp> {
  @override
  void initState() {
    super.initState();
    // Démarre le flux SSE compteur après le 1er frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(counterControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
```

- [ ] **Step 4 : Câbler la racine**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'ui/root_gate.dart';

void main() {
  runApp(const ProviderScope(child: PintesApp(home: RootGate())));
}
```

- [ ] **Step 5 : Lancer toute la suite + golden**

Run: `flutter test`
Expected: tous les tests PASS (smoke, format, models, api_client, session, sse, counter, feed, submission, profile, app_shell, golden).

- [ ] **Step 6 : Qualité finale**

```bash
dart format . && flutter analyze   # 0 issue
```

- [ ] **Step 7 : README**

`app/README.md` : prérequis (Flutter SDK, `flutter doctor`), démarrage backend (`back/` docker compose), lancement `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`, lancement des tests `flutter test`, structure des couches.

- [ ] **Step 8 : Commit**

```bash
git add -A && git commit -m "feat: root session gate + counter SSE bootstrap + fr-FR golden + README"
```

---

## Self-Review

- **Couverture spec** : onboarding appareil (T4), compteur temps réel SSE + monotone + reconnexion (T5), capture photo custom + +1 validé sur réponse serveur (T7), fil + like optimiste + pagination/pull-to-refresh (T6), profil léger myCount/streak (T8), placeholder rayé par teinte (T6, faute d'URL photo côté `/feed`), format fr-FR + golden (T2/T9), couches ui/state/data/models + theme tokens (T1), nav 3 onglets + slot Villes réservé + (+) central (T8), gestion erreurs (réessayer T7, reconnexion T5, permission caméra T7, listes vides/erreur T6/T8). Monétisation = teasers statiques hors périmètre (T8). Tooling `dart format`/`flutter analyze` à chaque commit.
- **Placeholders** : code réel fourni à chaque étape ; aucun « TODO »/« à compléter ». Le seul élément non couvert par test unitaire (UI caméra) est explicitement isolé, avec la logique testable extraite dans `SubmissionController`.
- **Cohérence des types** : `ApiClient` (records `({int number, int total, FeedItem item})`, etc.) consommés tels quels par `SubmissionController`/`FeedController` ; `applyTotal`/`prepend`/`bumpMyCount`/`toggleLike`/`start` nommés de façon cohérente entre T5–T8 ; `SessionState`/`SubmissionState` scellés cohérents entre définition et `switch`.

> Préalable d'exécution : **installer Flutter** (Task 0) avant toute tâche. Les services backend (`back/` docker compose) doivent tourner pour un run réel et les tests d'intégration manuels (les tests `flutter test` du plan utilisent `MockClient` et ne requièrent pas le backend).
