import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import 'providers.dart';

/// Erreur d'inscription destinée à être affichée telle quelle à l'utilisateur
/// (message déjà traduit / convivial).
class SignUpException implements Exception {
  const SignUpException(this.message);
  final String message;
  @override
  String toString() => message;
}

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

  /// Inscrit l'appareil. On NE passe PAS l'état global en `AsyncLoading`/`AsyncError`
  /// pour ne pas faire disparaître l'écran de login : succès → `Authenticated`,
  /// échec → [SignUpException] relancée pour affichage inline par l'écran.
  Future<void> signUp({required String pseudo, required String city}) async {
    try {
      final api = ref.read(apiClientProvider);
      final session = await api.createDevice(pseudo: pseudo, city: city);
      await ref.read(tokenStoreProvider).write(session.deviceToken);
      state = AsyncData(Authenticated(session.pseudo, session.city));
    } on ApiException catch (e) {
      throw SignUpException(_friendlyApiMessage(e));
    } catch (_) {
      throw const SignUpException(
        'Connexion impossible. Vérifie ton réseau et réessaie.',
      );
    }
  }

  String _friendlyApiMessage(ApiException e) {
    if (e.status >= 500) {
      return 'Nos serveurs font une pause. Réessaie dans un instant.';
    }
    return 'Impossible de te connecter pour le moment. Réessaie.';
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );
