import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feed_controller.dart';
import 'providers.dart';

class CounterState {
  const CounterState({this.total = 0, this.reconnecting = false});
  final int total;
  final bool reconnecting;
  CounterState copyWith({int? total, bool? reconnecting}) => CounterState(
    total: total ?? this.total,
    reconnecting: reconnecting ?? this.reconnecting,
  );
}

class CounterController extends Notifier<CounterState> {
  StreamSubscription<dynamic>? _sub;

  @override
  CounterState build() {
    ref.onDispose(() => _sub?.cancel());
    return const CounterState();
  }

  /// Total monotone : ignore tout recul.
  void applyTotal(int total) {
    if (total > state.total) {
      state = state.copyWith(total: total, reconnecting: false);
    }
  }

  Future<void> start() async {
    final api = ref.read(apiClientProvider);
    try {
      applyTotal(await api.getCounter());
    } catch (_) {}
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = ref
        .read(sseClientProvider)
        .connect('/counter/stream')
        .listen(
          (e) {
            final j = jsonDecode(e.data) as Map<String, dynamic>;
            switch (j['type']) {
              case 'counter':
                applyTotal(j['total'] as int);
              case 'feed_item':
                ref
                    .read(feedControllerProvider.notifier)
                    .prepend(j['item'] as Map<String, dynamic>);
            }
          },
          onError: (_) => _reconnect(),
          onDone: _reconnect,
        );
  }

  void _reconnect() {
    state = state.copyWith(reconnecting: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (ref.mounted) _restart();
    });
  }

  Future<void> _restart() async {
    final api = ref.read(apiClientProvider);
    try {
      applyTotal(await api.getCounter());
    } catch (_) {}
    _listen();
  }
}

final counterControllerProvider =
    NotifierProvider<CounterController, CounterState>(CounterController.new);
