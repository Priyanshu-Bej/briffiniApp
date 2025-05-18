class ModuleModel {
  final String id;
  final String title;
  final String description;
  final int order;

  ModuleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
  });

  factory ModuleModel.fromJson(Map<String, dynamic> json, String id) {
    return ModuleModel(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'order': order,
    };
  }
} 