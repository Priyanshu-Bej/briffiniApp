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
      List<ContentModel> allContents = [];

      try {
        // Get content from the videos subcollection
        QuerySnapshot videosDocs = await _firestore!
            .collection('modules')
            .doc(moduleId)
            .collection('content')
            .doc('videos')
            .collection('0')
            .get();
        
        print("Number of videos found: ${videosDocs.docs.length}");
        
        // Add videos to the content list
        for (var doc in videosDocs.docs) {
          print("Processing video: ${doc.id} - Data: ${doc.data()}");
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          // Add content type manually
          data['type'] = 'video';
          allContents.add(ContentModel.fromJson(data, doc.id));
        }
      } catch (e) {
        print("Error fetching videos: $e");
        // Continue to next collection instead of stopping
      }

      try {
        // Get content from the pdfs subcollection
        QuerySnapshot pdfsDocs = await _firestore!
            .collection('modules')
            .doc(moduleId)
            .collection('content')
            .doc('pdfs')
            .collection('0')
            .get();
        
        print("Number of PDFs found: ${pdfsDocs.docs.length}");
        
        // Add PDFs to the content list
        for (var doc in pdfsDocs.docs) {
          print("Processing PDF: ${doc.id} - Data: ${doc.data()}");
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          // Add content type manually
          data['type'] = 'pdf';
          allContents.add(ContentModel.fromJson(data, doc.id));
        }
      } catch (e) {
        print("Error fetching PDFs: $e");
        // Continue to next collection instead of stopping
      }

      try {
        // Get content from the notes subcollection
        QuerySnapshot notesDocs = await _firestore!
            .collection('modules')
            .doc(moduleId)
            .collection('content')
            .doc('notes')
            .collection('0')
            .get();
        
        print("Number of notes found: ${notesDocs.docs.length}");
        
        // Add notes to the content list
        for (var doc in notesDocs.docs) {
          print("Processing note: ${doc.id} - Data: ${doc.data()}");
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          // Add content type manually
          data['type'] = 'text';
          allContents.add(ContentModel.fromJson(data, doc.id));
        }
      } catch (e) {
        print("Error fetching notes: $e");
        // Continue instead of stopping
      }

      // If we found content, return it sorted by order
      if (allContents.isNotEmpty) {
        print("Total content items found: ${allContents.length}");
        
        // Sort all content by order
        allContents.sort((a, b) => a.order.compareTo(b.order));
        return allContents;
      }

      try {
        // Fallback: Try checking if there's a top-level content collection
        print("No nested content found, trying top-level content collection");
        QuerySnapshot topLevelContentDocs = await _firestore!
            .collection('content')
            .where('moduleId', isEqualTo: moduleId)
            .get();
        
        print("Number of top-level content found: ${topLevelContentDocs.docs.length}");
        
        if (topLevelContentDocs.docs.isNotEmpty) {
          List<ContentModel> topLevelContents = topLevelContentDocs.docs.map((doc) {
            print("Processing top level content: ${doc.id} - Data: ${doc.data()}");
            return ContentModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
          
          topLevelContents.sort((a, b) => a.order.compareTo(b.order));
          return topLevelContents;
        }
      } catch (e) {
        print("Error fetching top-level content: $e");
      }

      print("No content found for module $moduleId");
      return [];
    } catch (e) {
      print("Error getting module content: $e");
      print("Stack trace: ${StackTrace.current}");
      
      // Check if it's a permission error
      if (e.toString().contains('permission-denied')) {
        print("Permission denied error detected. This might be a security rule issue.");
      }
      
      throw e; // Re-throw to handle at UI level
    }
  }
}
