const List<(double, String)> _fractions = [
  (0.125, '⅛'),
  (0.25, '¼'),
  (1 / 3, '⅓'),
  (0.375, '⅜'),
  (0.5, '½'),
  (0.625, '⅝'),
  (2 / 3, '⅔'),
  (0.75, '¾'),
  (0.875, '⅞'),
];

/// Plain number with trailing zeros trimmed: 1.50 -> "1.5", 2.000 -> "2".
String formatNumber(double v, {int decimals = 3}) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Kitchen-friendly display: 0.5 -> "½", 1.75 -> "1¾", 2.0 -> "2".
String formatQuantity(double v) {
  if (v <= 0) return '0';
  final whole = v.floor();
  final frac = v - whole;
  if (frac < 0.03) {
    return whole == 0 ? formatNumber(v, decimals: 2) : '$whole';
  }
  if (frac > 0.97) return '${whole + 1}';
  for (final (value, glyph) in _fractions) {
    if ((frac - value).abs() < 0.03) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  return formatNumber(v, decimals: v >= 10 ? 1 : 2);
}

/// Parses "2", "0.5", "1/2", "1 1/2", "1½", "½", "1,5". Null if invalid/empty.
double? parseQuantity(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  var total = 0.0;
  var any = false;

  for (final (value, glyph) in _fractions) {
    if (s.contains(glyph)) {
      total += value;
      s = s.replaceAll(glyph, ' ');
      any = true;
    }
  }

  for (final part in s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty)) {
    if (part.contains('/')) {
      final nd = part.split('/');
      if (nd.length != 2) return null;
      final n = double.tryParse(nd[0]);
      final d = double.tryParse(nd[1]);
      if (n == null || d == null || d == 0) return null;
      total += n / d;
    } else {
      final v = double.tryParse(part.replaceAll(',', '.'));
      if (v == null) return null;
      total += v;
    }
    any = true;
  }
  return any ? total : null;
}

String formatMinutes(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}
