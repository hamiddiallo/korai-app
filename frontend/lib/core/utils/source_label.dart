/// Libellés des sources citées par l'IA.
class SourceLabel {
  const SourceLabel._();

  static final _url = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false);

  /// Sans chemin de dossier : « C:\Users\…\EMC-ORL.pdf · p. 97 » → « EMC-ORL.pdf · p. 97 ».
  /// La base documentaire du service IA a été indexée sous Windows et garde le chemin complet
  /// de chaque PDF ; d'anciennes réponses enregistrées le contiennent encore. Les URL et les
  /// titres ordinaires contenant « / » restent intacts.
  static String clean(String label) {
    final trimmed = label.trim();
    if (_url.hasMatch(trimmed)) return trimmed;
    final separator = trimmed.indexOf(' · ');
    final title = separator < 0 ? trimmed : trimmed.substring(0, separator);
    if (!title.contains(r'\') && !title.startsWith('/')) return trimmed;
    final parts = title.split(RegExp(r'[\\/]')).where((part) => part.trim().isNotEmpty);
    final name = parts.isEmpty ? title : parts.last;
    return separator < 0 ? name : '$name${trimmed.substring(separator)}';
  }

  /// Liste de sources reçue du serveur : libellés nettoyés, vides et doublons retirés.
  static List<String> cleanAll(Object? raw) {
    if (raw is! List) return const [];
    final labels = <String>[];
    for (final item in raw) {
      final label = clean(item.toString());
      if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
    }
    return labels;
  }
}
