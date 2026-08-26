import 'package:share_plus/share_plus.dart';

import '../config.dart';
import 'format.dart';

/// Opens the native share sheet with a festive invite message and the brand
/// link. Pass the live global [total] when available (e.g. from the home
/// counter) so the message carries the current progress toward the million —
/// the emotional hook that drives people to join.
Future<void> shareInvite({int? total}) async {
  final counted =
      total != null ? '${formatCountFr(total)} pintes déjà comptées. ' : '';
  final message =
      '🍺 On boit 1 000 000 de pintes ensemble sur Tchin.beer !\n'
      '${counted}Ramène ta pinte et fais grimper le compteur 👉 $inviteUrl';
  await SharePlus.instance.share(
    ShareParams(text: message, subject: 'Rejoins Tchin.beer 🍺'),
  );
}
