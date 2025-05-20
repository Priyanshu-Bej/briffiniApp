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

      // First, try fetching from the modules subcollection in the course document
      QuerySnapshot modulesSnapshot =
          await _firestore!
              .collection('courses')
              .doc(courseId)
              .collection('modules')
              .get();

      if (modulesSnapshot.docs.isNotEmpty) {
        print("Found ${modulesSnapshot.docs.length} modules in subcollection");
        List<ModuleModel> modules =
            modulesSnapshot.docs.map((doc) {
              return ModuleModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

        // Sort by order field manually (instead of using orderBy to avoid index issues)
        modules.sort((a, b) => a.order.compareTo(b.order));
        return modules;
      } else {
        // If no modules found in subcollection, try looking for a modules field in the course document
        print(
          "No modules found in subcollection, checking course document for moduleCount",
        );
        DocumentSnapshot courseDoc =
            await _firestore!.collection('courses').doc(courseId).get();

        if (courseDoc.exists) {
          Map<String, dynamic> courseData =
              courseDoc.data() as Map<String, dynamic>;
          if (courseData.containsKey('moduleCount') &&
              courseData['moduleCount'] > 0) {
            // If course has modules, try to fetch them directly from top-level modules collection
            print(
              "Course has modules according to moduleCount, fetching from top-level collection",
            );

            // Skip the ordering and just use the where clause to avoid index requirements
            QuerySnapshot modulesSnapshot =
                await _firestore!
                    .collection('modules')
                    .where('courseId', isEqualTo: courseId)
                    .get();

            if (modulesSnapshot.docs.isNotEmpty) {
              print(
                "Found ${modulesSnapshot.docs.length} modules in modules collection",
              );
              List<ModuleModel> modules =
                  modulesSnapshot.docs.map((doc) {
                    return ModuleModel.fromJson(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );
                  }).toList();

              // Sort manually instead of using Firestore's orderBy
              modules.sort((a, b) => a.order.compareTo(b.order));
              return modules;
            }
          }
        }

        // No modules found
        print("No modules found anywhere for course $courseId");
        return [];
      }
    } catch (e) {
      print("Error getting modules: $e");
      throw e; // Re-throw to handle at UI level
    }
  }

  // Get only published modules for a course (for student view)
  Future<List<ModuleModel>> getPublishedModules(String courseId) async {
    try {
      List<ModuleModel> allModules = await getModules(courseId);
      // Filter out modules where isPublished is false
      return allModules.where((module) => module.isPublished).toList();
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

      // Try getting all documents in the content collection
      QuerySnapshot contentDocs =
          await _firestore!
              .collection('courses')
              .doc(courseId)
              .collection('modules')
              .doc(moduleId)
              .collection('content')
              .get();

      print("Number of content documents found: ${contentDocs.docs.length}");

      if (contentDocs.docs.isNotEmpty) {
        print(
          "Content documents IDs: ${contentDocs.docs.map((doc) => doc.id).join(', ')}",
        );

        List<ContentModel> contents =
            contentDocs.docs.map((doc) {
              print("Processing content document: ${doc.id}");
              return ContentModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

        // Sort by order field manually
        contents.sort((a, b) => a.order.compareTo(b.order));
        return contents;
      } else {
        print("No documents found in content collection");
        return [];
      }
    } catch (e) {
      print("Error getting module content: $e");
      print("Stack trace: ${StackTrace.current}");
      throw e; // Re-throw to handle at UI level
    }
  }
}
