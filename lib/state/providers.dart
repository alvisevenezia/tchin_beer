import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/api_client.dart';
import '../data/token_store.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(httpClientProvider),
    baseUrl: apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
  ),
);
