class ContentModel {
  final String id;
  final String title;
  final String contentType; // 'text', 'video', 'pdf', etc.
  final String content;
  final int order;
  final String moduleId;

  ContentModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.content,
    required this.order,
    this.moduleId = '',
  });

  factory ContentModel.fromJson(Map<String, dynamic> json, String id) {
    // Debug logging to see what's in the JSON
    print("ContentModel.fromJson for $id: ${json.keys.toList()}");
    
    // Handle fields that might be coming with different names
    String contentValue = '';
    if (json.containsKey('url')) {
      contentValue = json['url']?.toString() ?? '';
      print("Found url: $contentValue");
    } else if (json.containsKey('fileUrl')) {
      contentValue = json['fileUrl']?.toString() ?? '';
      print("Found fileUrl: $contentValue");
    } else if (json.containsKey('content')) {
      contentValue = json['content']?.toString() ?? '';
    } else if (json.containsKey('text')) {
      contentValue = json['text']?.toString() ?? '';
    } else if (json.containsKey('videoUrl')) {
      contentValue = json['videoUrl']?.toString() ?? '';
    }
    
    // Handle fields that might be missing or in different formats
    String contentTypeValue = json['type']?.toString() ?? 'text';
    print("Content type: $contentTypeValue");
    
    // For order, default to the position in the array (0)
    int orderValue = 0;
    if (json.containsKey('order')) {
      var orderRaw = json['order'];
      if (orderRaw is int) {
        orderValue = orderRaw;
      } else if (orderRaw is String) {
        orderValue = int.tryParse(orderRaw) ?? 0;
      }
    } else if (json.containsKey('position')) {
      var positionRaw = json['position'];
      if (positionRaw is int) {
        orderValue = positionRaw;
      } else if (positionRaw is String) {
        orderValue = int.tryParse(positionRaw) ?? 0;
      }
    }
    
    // Use title from json or fallback
    String titleValue = json['title']?.toString() ?? (
      contentTypeValue == 'video' ? 'Video' : 
      contentTypeValue == 'pdf' ? 'PDF Document' : 
      'Content Item'
    );
    
    // Get moduleId
    String moduleIdValue = json['moduleId']?.toString() ?? '';
    
    return ContentModel(
      id: id,
      title: titleValue,
      contentType: contentTypeValue,
      content: contentValue,
      order: orderValue,
      moduleId: moduleIdValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'contentType': contentType,
      'content': content,
      'order': order,
      'moduleId': moduleId,
    };
  }
} 