class CourseModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json, String id) {
    return CourseModel(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
} 