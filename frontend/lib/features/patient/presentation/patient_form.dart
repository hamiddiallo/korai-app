import 'package:flutter/widgets.dart';

import '../../nurse/domain/patient.dart';

/// Champs d'identité du patient, partagés entre le profil et la
/// pré-consultation : ce qui est saisi d'un côté se retrouve de l'autre.
class PatientFormControllers {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final age = TextEditingController();
  final notes = TextEditingController();
  final sex = ValueNotifier<String>('F');

  bool _filled = false;

  /// Pré-remplit une seule fois à partir du dossier chargé.
  void fillOnce(Patient patient, {String? fallbackPhone}) {
    if (_filled) return;
    firstName.text = patient.firstName;
    lastName.text = patient.lastName;
    phone.text = patient.phone ?? fallbackPhone ?? '';
    address.text = patient.address ?? '';
    final birth = patient.birthDate;
    if (birth != null) {
      age.text = birth.replaceAll('Age: ', '').replaceAll(' ans', '').trim();
    }
    if (patient.sex != null) sex.value = patient.sex == 'M' ? 'M' : 'F';
    _filled = true;
  }

  /// « Age: 28 ans », format attendu par le dossier.
  String? get birthDateValue => age.text.trim().isEmpty ? null : 'Age: ${age.text.trim()} ans';

  void dispose() {
    for (final c in [firstName, lastName, phone, address, age, notes]) {
      c.dispose();
    }
    sex.dispose();
  }
}
