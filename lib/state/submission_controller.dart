import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'counter_controller.dart';
import 'feed_controller.dart';
import 'profile_controller.dart';
import 'providers.dart';

sealed class SubmissionState {
  const SubmissionState();
}

class Idle extends SubmissionState {
  const Idle();
}

class Submitting extends SubmissionState {
  const Submitting();
}

class Success extends SubmissionState {
  const Success(this.number, this.total, this.item);
  final int number;
  final int total;
  final FeedItem item;
}

class Failed extends SubmissionState {
  const Failed(this.error);
  final Object error;
}

class SubmissionController extends Notifier<SubmissionState> {
  @override
  SubmissionState build() => const Idle();

  Future<void> submit({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? tone,
  }) async {
    state = const Submitting();
    try {
      final res = await ref
          .read(apiClientProvider)
          .postPinte(
            bytes: bytes,
            filename: filename,
            contentType: contentType,
            tone: tone,
          );
      // Réponse serveur confirmée : appliquer aux autres états.
      ref.read(counterControllerProvider.notifier).applyTotal(res.total);
      ref.read(feedControllerProvider.notifier).prepend({
        'id': res.item.id,
        'number': res.item.number,
        'name': res.item.name,
        'city': res.item.city,
        'tone': res.item.tone,
        'likes': res.item.likes,
        'liked': res.item.liked,
        'photo_url': res.item.photoUrl,
      });
      ref.read(profileControllerProvider.notifier).bumpMyCount();
      state = Success(res.number, res.total, res.item);
    } catch (e) {
      state = Failed(e); // jamais Success sur échec
    }
  }

  void reset() => state = const Idle();
}

final submissionControllerProvider =
    NotifierProvider<SubmissionController, SubmissionState>(
      SubmissionController.new,
    );
