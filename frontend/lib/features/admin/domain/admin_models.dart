class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.healthFacility,
    this.professionalId,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? healthFacility;
  final String? professionalId;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
      role: json['role'].toString(),
      phone: json['phone']?.toString(),
      healthFacility: json['healthFacility']?.toString(),
      professionalId: json['professionalId']?.toString(),
    );
  }
}

class AdminPatient {
  const AdminPatient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.consentForAi,
    required this.consentForTeleExpertise,
    this.birthDate,
    this.sex,
    this.phone,
    this.address,
    this.deletedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? birthDate;
  final String? sex;
  final String? phone;
  final String? address;
  final bool consentForAi;
  final bool consentForTeleExpertise;
  final String? deletedAt;

  String get fullName => '$firstName $lastName';

  factory AdminPatient.fromJson(Map<String, dynamic> json) {
    return AdminPatient(
      id: json['id'].toString(),
      firstName: json['firstName'].toString(),
      lastName: json['lastName'].toString(),
      birthDate: json['birthDate']?.toString(),
      sex: json['sex']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      consentForAi: json['consentForAi'] == true,
      consentForTeleExpertise: json['consentForTeleExpertise'] == true,
      deletedAt: json['deletedAt']?.toString(),
    );
  }
}

class AdminConsultation {
  const AdminConsultation({
    required this.id,
    required this.patientId,
    required this.status,
    required this.urgency,
    required this.clinicalNarrative,
    required this.symptomLabels,
    required this.createdAt,
    required this.otoscopicImages,
    this.likelyDiagnosis,
    this.deletedAt,
  });

  final String id;
  final String patientId;
  final String status;
  final String urgency;
  final String clinicalNarrative;
  final List<String> symptomLabels;
  final String createdAt;
  final List<AdminOtoscopicImage> otoscopicImages;
  final String? likelyDiagnosis;
  final String? deletedAt;

  factory AdminConsultation.fromJson(Map<String, dynamic> json) {
    final aiResp = json['aiResponse'] as Map<String, dynamic>?;
    final likelyDiag = aiResp != null ? aiResp['likelyDiagnosis']?.toString() : null;

    final rawSymptoms = json['symptomLabels'];
    final List<String> symptoms = rawSymptoms is List
        ? rawSymptoms.map((e) => e.toString()).toList()
        : [];

    final rawImages = json['otoscopicImages'];
    final List<AdminOtoscopicImage> images = rawImages is List
        ? rawImages.map((e) => AdminOtoscopicImage.fromJson(e as Map<String, dynamic>)).toList()
        : [];

    return AdminConsultation(
      id: json['id'].toString(),
      patientId: json['patientId'].toString(),
      status: json['status'].toString(),
      urgency: json['urgency'].toString(),
      clinicalNarrative: json['clinicalNarrative']?.toString() ?? '',
      symptomLabels: symptoms,
      createdAt: json['createdAt'].toString(),
      otoscopicImages: images,
      likelyDiagnosis: likelyDiag,
      deletedAt: json['deletedAt']?.toString(),
    );
  }
}

class AdminOtoscopicImage {
  const AdminOtoscopicImage({
    required this.id,
    required this.earSide,
    required this.mimeType,
    this.description,
  });

  final String id;
  final String earSide;
  final String mimeType;
  final String? description;

  factory AdminOtoscopicImage.fromJson(Map<String, dynamic> json) {
    return AdminOtoscopicImage(
      id: json['id'].toString(),
      earSide: json['earSide'].toString(),
      mimeType: json['mimeType'].toString(),
      description: json['description']?.toString(),
    );
  }
}


class ClinicalReferenceItem {
  const ClinicalReferenceItem({
    required this.id,
    required this.type,
    required this.label,
    required this.isActive,
    required this.sortOrder,
    this.description,
    this.dangerScore = 0,
  });

  final String id;
  final String type;
  final String label;
  final String? description;
  final bool isActive;
  final int sortOrder;

  /// Score de danger 0–3 (alimente le calcul automatique d'urgence).
  final int dangerScore;

  factory ClinicalReferenceItem.fromJson(Map<String, dynamic> json) {
    return ClinicalReferenceItem(
      id: json['id'].toString(),
      type: json['type'].toString(),
      label: json['label'].toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] == true,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      dangerScore: int.tryParse(json['dangerScore']?.toString() ?? '') ?? 0,
    );
  }
}
