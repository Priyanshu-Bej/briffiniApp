class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String role;
  final List<String> assignedCourseIds;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.assignedCourseIds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      assignedCourseIds: List<String>.from(json['assignedCourseIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'role': role,
      'assignedCourseIds': assignedCourseIds,
    };
  }
} 