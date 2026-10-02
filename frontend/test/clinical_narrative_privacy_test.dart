import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/features/nurse/data/nurse_repository.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_consultation_view_model.dart';
import 'package:korai_frontend/features/patient/data/patient_repository.dart';
import 'package:korai_frontend/features/patient/presentation/patient_consultation_view_model.dart';

/// Le récit clinique part au serveur puis au service IA externe : il ne doit
/// contenir aucune donnée d'identité du patient.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectNoIdentity(String narrative) {
    for (final identity in ['Patient:', 'Telephone', 'Adresse', 'Awa', 'Diop', '77 123', 'Dakar']) {
      expect(narrative, isNot(contains(identity)), reason: identity);
    }
    expect(narrative, contains('Age: 34 ans'));
    expect(narrative, contains('Sexe: F'));
    expect(narrative, contains('Notes libres: douleur depuis 3 jours'));
  }

  test('récit du soignant : données cliniques uniquement', () async {
    final vm = NurseConsultationViewModel(repository: NurseRepository(ApiClient()));
    expectNoIdentity(vm.buildClinicalNarrative(age: '34', sex: 'F', notes: 'douleur depuis 3 jours'));
    await vm.close();
  });

  test('pré-consultation du patient : données cliniques uniquement', () async {
    final api = ApiClient();
    final vm = PatientConsultationViewModel(repository: PatientRepository(api), session: AuthCubit(apiClient: api));
    final narrative = vm.buildClinicalNarrative(age: '34', sex: 'F', notes: 'douleur depuis 3 jours');
    expectNoIdentity(narrative);
    expect(narrative, contains('pré-consultation remplie par le patient'));
    await vm.close();
  });
}
