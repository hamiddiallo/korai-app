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
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? address;
  final String? birthDate;
  final String? sex;
  final bool isValidated;

  String get fullName => '$firstName $lastName';

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
    );
  }
}
