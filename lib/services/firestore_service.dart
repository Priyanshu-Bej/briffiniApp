import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../main.dart'; // Import for isFirebaseInitialized

class FirestoreService {
  // Flag to indicate operational mode - default to true since we want dynamic data
  bool _isFirestoreAvailable = true;

  // Firebase instance
  FirebaseFirestore? _firestore;

  FirestoreService() {
    try {
      _firestore = FirebaseFirestore.instance;
      print("Firestore initialized successfully");
    } catch (e) {
      print("Failed to initialize Firestore: $e");
      _isFirestoreAvailable = false;
    }
  }

  // Get assigned courses for a user
  Future<List<CourseModel>> getAssignedCourses(List<String> courseIds) async {
    if (!_isFirestoreAvailable || courseIds.isEmpty) {
      print("Firestore not available or no course IDs provided");
      return [];
    }

    try {
      List<CourseModel> courses = [];

      for (String courseId in courseIds) {
        DocumentSnapshot courseDoc =
            await _firestore!.collection('courses').doc(courseId).get();

        if (courseDoc.exists) {
          courses.add(
            CourseModel.fromJson(
              courseDoc.data() as Map<String, dynamic>,
              courseDoc.id,
            ),
          );
        }
      }

      return courses;
    } catch (e) {
      print("Error getting assigned courses: $e");
      throw e; // Re-throw to handle at UI level
    }
  }

  // Get modules for a course
  Future<List<ModuleModel>> getModules(String courseId) async {
    if (!_isFirestoreAvailable) {
      print("Firestore not available");
      return [];
    }

    try {
      print("Fetching modules for course: $courseId");

      // Fetch directly from the top-level modules collection with courseId field
      QuerySnapshot modulesSnapshot =
          await _firestore!
              .collection('modules')
              .where('courseId', isEqualTo: courseId)
              .get();

      if (modulesSnapshot.docs.isNotEmpty) {
        print("Found ${modulesSnapshot.docs.length} modules in modules collection");
        List<ModuleModel> modules =
            modulesSnapshot.docs.map((doc) {
              print("Module data: ${doc.data()}");
              return ModuleModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

        // Sort by order field manually (instead of using orderBy to avoid index issues)
        modules.sort((a, b) => a.order.compareTo(b.order));
        return modules;
      }

      // No modules found
      print("No modules found for course $courseId");
      return [];
    } catch (e) {
      print("Error getting modules: $e");
      throw e; // Re-throw to handle at UI level
    }
  }

  // Get only published modules for a course (for student view)
  Future<List<ModuleModel>> getPublishedModules(String courseId) async {
    try {
      print("Fetching published modules for course: $courseId");
      
      // Fetch directly from modules collection with courseId AND isPublished = true
      QuerySnapshot modulesSnapshot =
          await _firestore!
              .collection('modules')
              .where('courseId', isEqualTo: courseId)
              .where('isPublished', isEqualTo: true)
              .get();
              
      if (modulesSnapshot.docs.isNotEmpty) {
        print("Found ${modulesSnapshot.docs.length} published modules");
        List<ModuleModel> modules =
            modulesSnapshot.docs.map((doc) {
              print("Published module data: ${doc.data()}");
              return ModuleModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

        // Sort by order field manually
        modules.sort((a, b) => a.order.compareTo(b.order));
        return modules;
      }
      
      print("No published modules found for course $courseId");
      return [];
    } catch (e) {
      print("Error getting published modules: $e");
      throw e;
    }
  }

  // Get content items for a module
  Future<List<ContentModel>> getModuleContent(
    String courseId,
    String moduleId,
  ) async {
    if (!_isFirestoreAvailable) {
      print("Firebase not available");
      return [];
    }

    try {
      print("Fetching content for module: $moduleId in course: $courseId");

      // First try to get content from the module's content collection
      QuerySnapshot contentDocs = await _firestore!
          .collection('modules')
          .doc(moduleId)
          .collection('content')
          .get();

      print("Number of content documents found: ${contentDocs.docs.length}");

      // If no content in module's subcollection, try the top-level content collection
      if (contentDocs.docs.isEmpty) {
        print("Trying to find content in top-level content collection");
        contentDocs = await _firestore!
            .collection('content')
            .where('moduleId', isEqualTo: moduleId)
            .get();
        
        print("Number of content documents found in top-level: ${contentDocs.docs.length}");
      }

      if (contentDocs.docs.isNotEmpty) {
        print(
          "Content documents IDs: ${contentDocs.docs.map((doc) => doc.id).join(', ')}",
        );

        List<ContentModel> contents =
            contentDocs.docs.map((doc) {
              print("Processing content document: ${doc.id} - Data: ${doc.data()}");
              return ContentModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

        // Sort by order field manually
        contents.sort((a, b) => a.order.compareTo(b.order));
        return contents;
      } else {
        print("No content documents found for module $moduleId");
        return [];
      }
    } catch (e) {
      print("Error getting module content: $e");
      print("Stack trace: ${StackTrace.current}");
      throw e; // Re-throw to handle at UI level
    }
  }
}
