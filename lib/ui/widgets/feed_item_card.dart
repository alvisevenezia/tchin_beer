import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../theme/tokens.dart';
import 'photo_frame.dart';
import 'reaction_widget.dart';

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class FeedItemCard extends StatelessWidget {
  const FeedItemCard({
    super.key,
    required this.item,
    required this.onLike,
    required this.onReact,
    required this.onRedCard,
    this.availableReactions = const [],
  });
  final FeedItem item;
  final VoidCallback onLike;
  final ValueChanged<String> onReact;
  final VoidCallback onRedCard;
  final List<String> availableReactions;

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.foam,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReactionPicker(
        availableReactions: availableReactions,
        onSelect: onReact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.toneColor(item.tone);
    final stripes = AppTokens.toneStripes(item.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _openPicker(context),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: PhotoFrame(
                frame: item.frame,
                radius: AppTokens.radiusThumb,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusThumb),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: item.invalidated
                            ? const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _StripedPainter(
                                light: stripes.light,
                                dark: stripes.dark,
                              ),
                            ),
                            if (item.photoUrl != null)
                              Image.network(
                                item.photoUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _Chip('📍 ${item.city}'),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: _NumChip('#${item.number}'),
                      ),
                      if (item.reactions.isNotEmpty)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _ReactionsOverlay(reactions: item.reactions),
                        ),
                      if (item.invalidated)
                        const Positioned.fill(child: _InvalidatedOverlay()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Avatar(
                name: item.name,
                avatarUrl: item.avatarUrl,
                accent: accent,
                isPremium: item.isPremium,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'vient de poser sa pinte',
                          style: TextStyle(
                            color: AppTokens.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.postedAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(item.postedAt!),
                            style: const TextStyle(
                              color: AppTokens.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!item.isMine) ...[
                _RedCardButton(item: item, onRedCard: onRedCard),
                const SizedBox(width: 8),
              ],
              _LikeButton(item: item, accent: accent, onLike: onLike),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvalidatedOverlay extends StatelessWidget {
  const _InvalidatedOverlay();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0x99000000),
    alignment: Alignment.center,
    child: const Text(
      'Invalidée',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _RedCardButton extends StatelessWidget {
  const _RedCardButton({required this.item, required this.onRedCard});
  final FeedItem item;
  final VoidCallback onRedCard;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onRedCard,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.myRedCard ? AppTokens.live : AppTokens.foam,
        border: item.myRedCard ? null : Border.all(color: AppTokens.rail),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Icon(
        Icons.flag,
        size: 16,
        color: item.myRedCard ? Colors.white : AppTokens.muted,
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.accent,
    this.avatarUrl,
    this.isPremium = false,
  });
  final String name;
  final Color accent;
  final String? avatarUrl;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (avatarUrl != null) {
      avatar = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(name: name, accent: accent),
        ),
      );
    } else {
      avatar = _Fallback(name: name, accent: accent);
    }
    if (!isPremium) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -2,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTokens.amber, AppTokens.coral]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Text(
              '✨',
              style: TextStyle(fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name, required this.accent});
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 19,
    backgroundColor: accent,
    child: Text(
      name.characters.first,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xC72A1206),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFFE3C2),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

class _NumChip extends StatelessWidget {
  const _NumChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xD1FFFBF2),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: AppTokens.ink,
      ),
    ),
  );
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.item,
    required this.accent,
    required this.onLike,
  });
  final FeedItem item;
  final Color accent;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onLike,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: item.liked ? accent : AppTokens.foam,
        border: item.liked ? null : Border.all(color: AppTokens.rail),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '♥ ${item.likes}',
        style: TextStyle(
          color: item.liked ? Colors.white : AppTokens.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ReactionsOverlay extends StatelessWidget {
  const _ReactionsOverlay({required this.reactions});
  final Map<String, int> reactions;

  @override
  Widget build(BuildContext context) {
    final top = kReactionOrder.where(reactions.containsKey).take(3).toList();
    final total = reactions.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xD1FFFBF2),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in top)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: ReactionIcon(type: type, size: 16),
            ),
          const SizedBox(width: 2),
          Text(
            '$total',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// Raies diagonales 45° selon le handoff
class _StripedPainter extends CustomPainter {
  const _StripedPainter({required this.light, required this.dark});
  final Color light, dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    const stripe = 16.0;
    final extent = size.width + size.height;
    for (var i = -size.height; i < extent; i += stripe * 2) {
      final path = Path()
        ..moveTo(i, 0)
        ..lineTo(i + stripe, 0)
        ..lineTo(i + stripe + size.height, size.height)
        ..lineTo(i + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StripedPainter old) =>
      old.light != light || old.dark != dark;
}
