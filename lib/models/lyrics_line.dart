class LyricsLine {
  final Duration start;
  final String text;
  final String? translation;

  const LyricsLine({
    required this.start,
    required this.text,
    this.translation,
  });
}

final _lrcTag = RegExp(r'\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Parses LRC timestamps when present; otherwise char-weighted timing over [total].
List<LyricsLine> parseLyricsToLines(String? raw, Duration total, {String? translationRaw}) {
  if (raw == null || raw.trim().isEmpty) return [];

  final rawLines = raw.split(RegExp(r'\r?\n'));
  final hasLrc = rawLines.any((l) => _lrcTag.hasMatch(l));

  if (hasLrc) {
    final parsed = <LyricsLine>[];
    for (final line in rawLines) {
      final tags = _lrcTag.allMatches(line).toList();
      if (tags.isEmpty) continue;
      final text = line.replaceAll(_lrcTag, '').trim();
      if (text.isEmpty) continue;
      for (final tag in tags) {
        final min = int.tryParse(tag.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(tag.group(2) ?? '0') ?? 0;
        var ms = 0;
        final frac = tag.group(3);
        if (frac != null && frac.isNotEmpty) {
          final padded = frac.padRight(3, '0');
          ms = int.tryParse(padded.substring(0, padded.length.clamp(0, 3))) ?? 0;
        }
        parsed.add(LyricsLine(
          start: Duration(minutes: min, seconds: sec, milliseconds: ms),
          text: text,
        ));
      }
    }
    parsed.sort((a, b) => a.start.compareTo(b.start));
    if (parsed.isNotEmpty) return _attachTranslations(parsed, translationRaw);
  }

  final textLines = rawLines
      .map((l) => l.replaceAll(_lrcTag, '').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (textLines.isEmpty) return [];

  final dur = total.inMilliseconds > 5000 ? total : const Duration(minutes: 3, seconds: 30);
  final introMs = (dur.inMilliseconds * 0.1).round();
  final outroMs = (dur.inMilliseconds * 0.05).round();
  final usableMs = dur.inMilliseconds - introMs - outroMs;

  final weights = textLines.map((l) => l.length.clamp(10, 120)).toList();
  final weightSum = weights.fold<int>(0, (a, b) => a + b);

  var cursor = introMs;
  final lines = <LyricsLine>[];
  for (var i = 0; i < textLines.length; i++) {
    final share = weightSum > 0 ? weights[i] / weightSum : 1 / textLines.length;
    var lineMs = (usableMs * share).round();
    lineMs = lineMs.clamp(1800, 14000);
    lines.add(LyricsLine(start: Duration(milliseconds: cursor), text: textLines[i]));
    cursor += lineMs;
  }

  return _attachTranslations(lines, translationRaw);
}

List<LyricsLine> _attachTranslations(List<LyricsLine> lines, String? translationRaw) {
  if (translationRaw == null || translationRaw.trim().isEmpty) return lines;
  final trans = translationRaw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (trans.isEmpty) return lines;
  return List.generate(lines.length, (i) {
    final t = i < trans.length ? trans[i].trim() : null;
    return LyricsLine(start: lines[i].start, text: lines[i].text, translation: t);
  });
}

@Deprecated('Use parseLyricsToLines')
List<LyricsLine> parseLyricsText(String? raw, Duration total, {String? translationRaw}) =>
    parseLyricsToLines(raw, total, translationRaw: translationRaw);
