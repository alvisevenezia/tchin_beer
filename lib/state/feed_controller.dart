import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'providers.dart';

class FeedState {
  const FeedState({this.items = const [], this.cursor, this.hasMore = true});
  final List<FeedItem> items;
  final String? cursor;
  final bool hasMore;
  FeedState copyWith({List<FeedItem>? items, String? cursor, bool? hasMore}) =>
      FeedState(
        items: items ?? this.items,
        cursor: cursor,
        hasMore: hasMore ?? this.hasMore,
      );
}

class FeedController extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final page = await ref.read(apiClientProvider).getFeed();
    return FeedState(
      items: page.items,
      cursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.cursor == null) return;
    final page = await ref.read(apiClientProvider).getFeed(cursor: cur.cursor);
    state = AsyncData(
      cur.copyWith(
        items: [...cur.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.nextCursor != null,
      ),
    );
  }

  void prepend(Map<String, dynamic> json) {
    final item = FeedItem.fromJson(json);
    final cur = state.value ?? const FeedState();
    if (cur.items.any((e) => e.id == item.id)) return; // dédupe
    state = AsyncData(cur.copyWith(items: [item, ...cur.items]));
  }

  Future<void> toggleLike(String id) async {
    final cur = state.value;
    if (cur == null) return;
    // Optimiste : flip immédiat.
    final optimistic = cur.items
        .map(
          (e) => e.id == id
              ? e.copyWith(liked: !e.liked, likes: e.likes + (e.liked ? -1 : 1))
              : e,
        )
        .toList();
    state = AsyncData(cur.copyWith(items: optimistic));
    try {
      final res = await ref.read(apiClientProvider).toggleLike(id);
      final reconciled = state.value!.items
          .map(
            (e) =>
                e.id == id ? e.copyWith(liked: res.liked, likes: res.likes) : e,
          )
          .toList();
      state = AsyncData(state.value!.copyWith(items: reconciled));
    } catch (_) {
      state = AsyncData(cur); // rollback
    }
  }

  Future<void> react(String id, String type) async {
    final cur = state.value;
    if (cur == null) return;
    final target = cur.items.firstWhere((e) => e.id == id);
    // Optimiste : même type retapé == toggle off (miroir de la logique backend).
    final optimisticType = target.myReaction == type ? null : type;
    final optimisticReactions = Map<String, int>.from(target.reactions);
    if (target.myReaction != null) {
      final n = (optimisticReactions[target.myReaction!] ?? 1) - 1;
      if (n <= 0) {
        optimisticReactions.remove(target.myReaction!);
      } else {
        optimisticReactions[target.myReaction!] = n;
      }
    }
    if (optimisticType != null) {
      optimisticReactions[optimisticType] =
          (optimisticReactions[optimisticType] ?? 0) + 1;
    }
    final optimisticItems = cur.items
        .map(
          (e) => e.id == id
              ? e.withReaction(
                  reactions: optimisticReactions,
                  myReaction: optimisticType,
                )
              : e,
        )
        .toList();
    state = AsyncData(cur.copyWith(items: optimisticItems));
    try {
      final res = await ref.read(apiClientProvider).addReaction(id, type);
      final reconciled = state.value!.items
          .map(
            (e) => e.id == id
                ? e.withReaction(
                    reactions: res.reactions,
                    myReaction: res.myReaction,
                  )
                : e,
          )
          .toList();
      state = AsyncData(state.value!.copyWith(items: reconciled));
    } catch (_) {
      state = AsyncData(cur); // rollback
    }
  }
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);
