import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'providers.dart';

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() => ref.read(apiClientProvider).getMe();

  void bumpMyCount() {
    final p = state.value;
    if (p == null) return;
    state = AsyncData(
      Profile(
        pseudo: p.pseudo,
        city: p.city,
        myCount: p.myCount + 1,
        streak: p.streak,
      ),
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile>(ProfileController.new);
