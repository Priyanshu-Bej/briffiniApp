class ModuleModel {
  final String id;
  final String title;
  final String description;
  final int order;
  final bool isPublished;
  final String courseId;

  ModuleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    this.isPublished = true,
    required this.courseId,
  });

  factory ModuleModel.fromJson(Map<String, dynamic> json, String id) {
    return ModuleModel(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      isPublished: json['isPublished'] ?? true,
      courseId: json['courseId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'order': order,
      'isPublished': isPublished,
      'courseId': courseId,
    };
  }
} 