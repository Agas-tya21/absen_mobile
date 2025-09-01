// lib/models/user.dart

class User {
  final String nik;
  final String nama;
  final String email;

  User({required this.nik, required this.nama, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      nik: json['nik'],
      nama: json['nama'],
      email: json['email'],
    );
  }
}