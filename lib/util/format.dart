/// Total formaté fr-FR : séparateurs de milliers = espace fine insécable (U+202F).
String formatCountFr(int value) {
  const sep = ' ';
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(sep);
    buf.write(s[i]);
  }
  return buf.toString();
}
