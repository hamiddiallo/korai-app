/// Mise en forme du texte de diagnostic renvoyé par l'IA. Il arrive souvent
/// sous forme de rapport numéroté (« 1. Causes probables », « 2. Signes
/// associés »…) : on en tire un titre court et des sections lisibles.
class DiagnosisText {
  const DiagnosisText._();

  static final _numbered = RegExp(r'^\d+\s*[\.\)]\s*(.+)$');
  static final _markdownHeading = RegExp(r'^#{1,4}\s*(.+)$');
  static final _technicalFailure = RegExp(
    r'^\s*(échec|echec|erreur|error|failed|timeout|service ia indisponible|analyse (ia )?indisponible)',
    caseSensitive: false,
  );

  /// `true` si le texte n'est qu'un message d'échec technique.
  static bool isTechnicalFailure(String? text) => text != null && _technicalFailure.hasMatch(text);

  static String _clean(String line) =>
      line.replaceAll('**', '').replaceAll('__', '').replaceFirst(RegExp(r'^[-*•]\s+'), '• ').trim();

  /// Titre de section : court, numéroté ou en titre markdown, sans point final.
  static String? _heading(String line) {
    final l = _clean(line);
    final m = _markdownHeading.firstMatch(l) ?? _numbered.firstMatch(l);
    final candidate = m?.group(1)?.trim() ?? (l.endsWith(':') ? l.substring(0, l.length - 1).trim() : null);
    if (candidate == null || candidate.isEmpty || candidate.length > 50 || candidate.endsWith('.')) return null;
    return candidate;
  }

  /// Sections du rapport (titre facultatif + contenu).
  static List<({String? title, String body})> sections(String? text) {
    final t = text?.trim();
    if (t == null || t.isEmpty) return const [];
    final result = <({String? title, String body})>[];
    String? title;
    final body = <String>[];
    void flush() {
      if (title != null || body.isNotEmpty) result.add((title: title, body: body.join('\n').trim()));
      title = null;
      body.clear();
    }

    for (final raw in t.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final h = _heading(line);
      if (h != null) {
        flush();
        title = h;
      } else {
        body.add(_clean(line));
      }
    }
    flush();
    return result;
  }

  /// Première phrase utile : ce qui s'affiche dans les listes et en titre.
  static String headline(String? text, {String fallback = 'Diagnostic non précisé'}) {
    for (final s in sections(text)) {
      final firstLine = s.body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      if (firstLine.isNotEmpty) return firstLine.replaceFirst(RegExp(r'^•\s*'), '');
      if (s.title != null) return s.title!;
    }
    return fallback;
  }

  /// `true` si le texte contient plus que son titre (rapport à déplier).
  static bool hasDetails(String? text) {
    final s = sections(text);
    return s.length > 1 || (s.isNotEmpty && s.first.body.contains('\n'));
  }
}
