import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/counter_controller.dart';
import '../state/feed_controller.dart';
import '../state/profile_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/feed_item_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    final availableReactions = ref
        .watch(profileControllerProvider)
        .maybeWhen(
          data: (p) => p.availableReactions,
          orElse: () => const <String>[],
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.screenPadH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const _ProgressHeader(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Le fil', style: displayStyle(size: 30)),
                const Spacer(),
                feed.maybeWhen(
                  data: (state) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE3D6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${state.items.length}',
                      style: const TextStyle(
                        color: AppTokens.coral,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
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
                            onReact: (type) => ref
                                .read(feedControllerProvider.notifier)
                                .react(state.items[i].id, type),
                            onRedCard: () => ref
                                .read(feedControllerProvider.notifier)
                                .toggleRedCard(state.items[i].id),
                            availableReactions: availableReactions,
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

class _ProgressHeader extends ConsumerWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterControllerProvider);
    final pct = (counter.total / 1000000).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LiveIndicator(reconnecting: counter.reconnecting),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${_fmt(counter.total)} / 1 000 000 pintes',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTokens.ink,
                ),
              ),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(1).replaceAll('.', ',')} %',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTokens.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 7,
          decoration: BoxDecoration(
            color: AppTokens.rail,
            borderRadius: BorderRadius.circular(100),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTokens.progressGradient,
                borderRadius: BorderRadius.all(Radius.circular(100)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator({required this.reconnecting});
  final bool reconnecting;
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 1.0, end: 0.2).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.reconnecting ? AppTokens.muted : AppTokens.live;
    final dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return widget.reconnecting
        ? dot
        : FadeTransition(opacity: _opacity, child: dot);
  }
}
