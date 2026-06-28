import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusThumb),
                color: accent.withValues(alpha: 0.18),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Chip('📍 ${item.city}'),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _Chip('#${item.number}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: accent,
                child: Text(
                  item.name.characters.first,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'vient de poser sa pinte',
                      style: TextStyle(color: AppTokens.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _LikeButton(item: item, onLike: onLike),
            ],
          ),
        ],
      ),
    );
  }
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
      ),
    ),
  );
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
}
