class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String role;
  final List<String> assignedCourseIds;
  final String? password;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.assignedCourseIds,
    this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      assignedCourseIds: List<String>.from(json['assignedCourseIds'] ?? []),
      password: json['password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'role': role,
      'assignedCourseIds': assignedCourseIds,
      'password': password,
    };
  }
}
