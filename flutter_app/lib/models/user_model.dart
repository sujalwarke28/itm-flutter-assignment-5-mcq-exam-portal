import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'student' | 'admin'
  final String? photoUrl;
  final String? photoPublicId;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    this.photoPublicId,
    this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      photoUrl: map['photoUrl'] as String?,
      photoPublicId: map['photoPublicId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'photoPublicId': photoPublicId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({String? name, String? photoUrl, String? photoPublicId, DateTime? lastLogin}) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      role: role,
      photoUrl: photoUrl ?? this.photoUrl,
      photoPublicId: photoPublicId ?? this.photoPublicId,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
