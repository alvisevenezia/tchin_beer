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
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );
