import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/feed_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/feed_item_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.screenPadH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        onRefresh: () =>
                            ref.read(feedControllerProvider.notifier).refresh(),
                        child: ListView.builder(
                          itemCount: state.items.length,
                          itemBuilder: (_, i) => FeedItemCard(
                            item: state.items[i],
                            onLike: () => ref
                                .read(feedControllerProvider.notifier)
                                .toggleLike(state.items[i].id),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
