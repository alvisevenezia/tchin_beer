import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'providers.dart';

/// Stats premium — uniquement chargées si le compte est premium.
final premiumStatsProvider = FutureProvider<PremiumStats?>((ref) async {
  final profile = await ref.watch(profileControllerProvider.future);
  if (!profile.isPremium) return null;
  return ref.read(apiClientProvider).getPremiumStats();
});

class ProfileController extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() => ref.read(apiClientProvider).getMe();

  void bumpMyCount() {
    final p = state.value;
    if (p == null) return;
    state = AsyncData(Profile(
      pseudo: p.pseudo,
      city: p.city,
      myCount: p.myCount + 1,
      streak: p.streak,
      isPremium: p.isPremium,
      frame: p.frame,
      avatarUrl: p.avatarUrl,
      purchasedFrames: p.purchasedFrames,
      availableReactions: p.availableReactions,
    ));
  }

  Future<void> changeCity(String city) async {
    final p = state.value;
    if (p == null) return;
    await ref.read(apiClientProvider).updateCity(city);
    state = AsyncData(Profile(
      pseudo: p.pseudo,
      city: city,
      myCount: p.myCount,
      streak: p.streak,
      isPremium: p.isPremium,
      frame: p.frame,
      avatarUrl: p.avatarUrl,
      purchasedFrames: p.purchasedFrames,
      availableReactions: p.availableReactions,
    ));
  }

  Future<void> activatePremium() async {
    final p = state.value;
    if (p == null) return;
    await ref.read(apiClientProvider).activatePremium();
    state = AsyncData(Profile(
      pseudo: p.pseudo,
      city: p.city,
      myCount: p.myCount,
      streak: p.streak,
      isPremium: true,
      frame: p.frame,
      avatarUrl: p.avatarUrl,
      purchasedFrames: p.purchasedFrames,
      availableReactions: p.availableReactions,
    ));
  }

  Future<void> changeFrame(String? frame) async {
    final p = state.value;
    if (p == null) return;
    await ref.read(apiClientProvider).updateFrame(frame);
    state = AsyncData(Profile(
      pseudo: p.pseudo,
      city: p.city,
      myCount: p.myCount,
      streak: p.streak,
      isPremium: p.isPremium,
      frame: frame,
      avatarUrl: p.avatarUrl,
      purchasedFrames: p.purchasedFrames,
      availableReactions: p.availableReactions,
    ));
  }

  Future<void> buyFrame(String frameId) async {
    final p = state.value;
    if (p == null) return;
    final frames = await ref.read(apiClientProvider).buyFrame(frameId);
    state = AsyncData(p.copyWithPurchasedFrames(frames));
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final p = state.value;
    if (p == null) return;
    final url = await ref.read(apiClientProvider).uploadAvatar(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    state = AsyncData(Profile(
      pseudo: p.pseudo,
      city: p.city,
      myCount: p.myCount,
      streak: p.streak,
      isPremium: p.isPremium,
      frame: p.frame,
      avatarUrl: url,
      purchasedFrames: p.purchasedFrames,
      availableReactions: p.availableReactions,
    ));
  }

  Future<void> buyPack(String packId) async {
    if (state.value == null) return;
    await ref.read(apiClientProvider).buyPack(packId);
    state = AsyncData(await ref.read(apiClientProvider).getMe());
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile>(ProfileController.new);
