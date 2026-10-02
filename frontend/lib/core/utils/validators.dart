/// Validateurs de formulaire alignés sur les schémas du backend (zod).
/// Chaque message dit quoi corriger.
class KValidators {
  const KValidators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label : champ obligatoire.' : null;

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Adresse e-mail : champ obligatoire.';
    if (!_emailRe.hasMatch(s)) {
      return 'Adresse e-mail invalide (exemple : nom@domaine.sn).';
    }
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Mot de passe : champ obligatoire.';
    if (s.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
    return null;
  }

  static String? minLength(String? v, String label, int min) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$label : champ obligatoire.';
    if (s.length < min) return '$label : $min caractères minimum.';
    return null;
  }

  static String? optionalMinLength(String? v, String label, int min) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return s.length < min ? '$label : $min caractères minimum.' : null;
  }

  static String? phoneOptional(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (!RegExp(r'^[+0-9 ().-]{5,}$').hasMatch(s)) {
      return 'Numéro de téléphone invalide (exemple : 77 123 45 67).';
    }
    return null;
  }

  static String? age(String? v, {bool required = true}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Âge : champ obligatoire.' : null;
    final n = int.tryParse(s);
    if (n == null || n < 0 || n > 120) return 'Âge invalide : entre 0 et 120 ans.';
    return null;
  }
}
