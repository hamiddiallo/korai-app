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
  });

  final String id;
  final String type;
  final String label;
  final String? description;
  final bool isActive;
  final int sortOrder;

  factory ClinicalReferenceItem.fromJson(Map<String, dynamic> json) {
    return ClinicalReferenceItem(
      id: json['id'].toString(),
      type: json['type'].toString(),
      label: json['label'].toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] == true,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }
}
