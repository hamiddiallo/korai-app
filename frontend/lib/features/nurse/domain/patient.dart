class Patient {
  const Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.address,
    this.birthDate,
    this.sex,
    this.isValidated = true,
    this.consentForAi = false,
    this.consentForTeleExpertise = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? address;
  final String? birthDate;
  final String? sex;
  final bool isValidated;

  /// Accord du patient pour l'analyse par l'IA (vérifié par le serveur).
  final bool consentForAi;

  /// Accord du patient pour le partage de son dossier avec un spécialiste.
  final bool consentForTeleExpertise;

  String get fullName => '$firstName $lastName';

  Patient withConsents({required bool ai, required bool teleExpertise}) => Patient(
        id: id,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        address: address,
        birthDate: birthDate,
        sex: sex,
        isValidated: isValidated,
        consentForAi: ai,
        consentForTeleExpertise: teleExpertise,
      );

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'].toString(),
      firstName: json['firstName'].toString(),
      lastName: json['lastName'].toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      birthDate: json['birthDate']?.toString(),
      sex: json['sex']?.toString(),
      isValidated: json['isValidated'] == true,
      consentForAi: json['consentForAi'] == true,
      consentForTeleExpertise: json['consentForTeleExpertise'] == true,
    );
  }
}
