/// Lecture de l'âge d'un patient.
///
/// Le champ `birthDate` contient selon l'origine une vraie date ISO
/// (`1998-04-12`) ou l'âge saisi en consultation (`Age: 28`, `Age: 28 ans`).
/// Cette classe sait lire les deux et n'expose jamais le format brut.
class PatientAge {
  const PatientAge._();

  static final _ageRe = RegExp(r'(\d{1,3})');

  static int? years(String? birthDate) {
    final raw = birthDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date != null) {
      final now = DateTime.now();
      var age = now.year - date.year;
      if (now.month < date.month || (now.month == date.month && now.day < date.day)) age--;
      return age < 0 ? null : age;
    }
    final match = _ageRe.firstMatch(raw);
    if (match == null) return null;
    final n = int.tryParse(match.group(1)!);
    return (n == null || n > 130) ? null : n;
  }

  /// « 28 ans », « 1 an » ou « Âge non renseigné ».
  static String label(String? birthDate) {
    final y = years(birthDate);
    if (y == null) return 'Âge non renseigné';
    return y <= 1 ? '$y an' : '$y ans';
  }
}
