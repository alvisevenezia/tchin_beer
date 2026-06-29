import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import 'providers.dart';

class RankingsUiState {
  const RankingsUiState({required this.period, required this.data});
  final String period;
  final AsyncValue<Rankings> data;
  RankingsUiState copyWith({String? period, AsyncValue<Rankings>? data}) =>
      RankingsUiState(period: period ?? this.period, data: data ?? this.data);
}

class RankingsController extends Notifier<RankingsUiState> {
  Timer? _debounce;

  @override
  RankingsUiState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const RankingsUiState(period: 'day', data: AsyncLoading());
  }

  void setPeriod(String p) {
    if (p == state.period) return;
    state = state.copyWith(period: p, data: const AsyncLoading());
    refresh();
  }

  Future<void> refresh() async {
    final period = state.period;
    try {
      final r = await ref.read(apiClientProvider).getRankings(period: period);
      if (!ref.mounted || period != state.period) return;
      state = state.copyWith(data: AsyncData(r));
    } catch (e, st) {
      if (!ref.mounted || period != state.period) return;
      state = state.copyWith(data: AsyncError(e, st));
    }
  }

  /// Signalé par le flux SSE quand une pinte modifie le classement.
  void onRemoteChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (ref.mounted) refresh();
    });
  }
}

final rankingsControllerProvider =
    NotifierProvider<RankingsController, RankingsUiState>(RankingsController.new);

/// Rang de la ville de l'utilisateur sur la semaine (pour le profil), indépendant
/// de la période affichée sur l'écran Villes.
final myWeekCityRankProvider = FutureProvider<CityRank?>((ref) async {
  final r = await ref.watch(apiClientProvider).getRankings(period: 'week', limit: 1);
  return r.me;
});
