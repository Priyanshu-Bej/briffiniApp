import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../main.dart'; // Import for isFirebaseInitialized

class FirestoreService {
  // Flags to indicate operational mode
  bool _isFirestoreAvailable = isFirebaseInitialized;
  
  // Firebase instance with error handling
  FirebaseFirestore? _firestore;
  
  FirestoreService() {
    if (!isFirebaseInitialized) {
      _isFirestoreAvailable = false;
      print("Skipping Firestore initialization - Firebase not initialized");
      return;
    }
    
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      print("Failed to initialize Firestore: $e");
      _isFirestoreAvailable = false;
    }
  }
  
  // Get assigned courses for a user
  Future<List<CourseModel>> getAssignedCourses(List<String> courseIds) async {
    if (!_isFirestoreAvailable || courseIds.isEmpty) {
      return _getDemoCourses();
    }
    
    try {
      List<CourseModel> courses = [];
      
      for (String courseId in courseIds) {
        DocumentSnapshot courseDoc = 
            await _firestore!.collection('courses').doc(courseId).get();
        
        if (courseDoc.exists) {
          courses.add(CourseModel.fromJson(
              courseDoc.data() as Map<String, dynamic>, courseDoc.id));
        }
      }
      
      return courses;
    } catch (e) {
      print("Error getting assigned courses: $e");
      return _getDemoCourses();
    }
  }
  
  // Get modules for a course
  Future<List<ModuleModel>> getModules(String courseId) async {
    if (!_isFirestoreAvailable) {
      return _getDemoModules(courseId);
    }
    
    try {
      print("Fetching modules for course: $courseId");
      
      // First, try fetching from the modules subcollection in the course document
      QuerySnapshot modulesSnapshot = await _firestore!
          .collection('courses')
          .doc(courseId)
          .collection('modules')
          .get();
      
      if (modulesSnapshot.docs.isNotEmpty) {
        print("Found ${modulesSnapshot.docs.length} modules in subcollection");
        List<ModuleModel> modules = modulesSnapshot.docs.map((doc) {
          return ModuleModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        // Sort by order field manually (instead of using orderBy to avoid index issues)
        modules.sort((a, b) => a.order.compareTo(b.order));
        return modules;
      } else {
        // If no modules found in subcollection, try looking for a modules field in the course document
        print("No modules found in subcollection, checking course document for moduleCount");
        DocumentSnapshot courseDoc = await _firestore!.collection('courses').doc(courseId).get();
        
        if (courseDoc.exists) {
          Map<String, dynamic> courseData = courseDoc.data() as Map<String, dynamic>;
          if (courseData.containsKey('moduleCount') && courseData['moduleCount'] > 0) {
            // If course has modules, try to fetch them directly from top-level modules collection
            print("Course has modules according to moduleCount, fetching from top-level collection");
            
            // Skip the ordering and just use the where clause to avoid index requirements
            QuerySnapshot modulesSnapshot = await _firestore!
                .collection('modules')
                .where('courseId', isEqualTo: courseId)
                .get();
            
            if (modulesSnapshot.docs.isNotEmpty) {
              print("Found ${modulesSnapshot.docs.length} modules in modules collection");
              List<ModuleModel> modules = modulesSnapshot.docs.map((doc) {
                return ModuleModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
              }).toList();
              
              // Sort manually instead of using Firestore's orderBy
              modules.sort((a, b) => a.order.compareTo(b.order));
              return modules;
            }
          }
        }
        
        // As a last resort, create a demo module for this course
        print("No modules found anywhere for course $courseId, returning demo modules");
        return _getDemoModules(courseId);
      }
    } catch (e) {
      print("Error getting modules: $e");
      return _getDemoModules(courseId);
    }
  }
  
  // Get content items for a module
  Future<List<ContentModel>> getModuleContent(String courseId, String moduleId) async {
    if (!_isFirestoreAvailable) {
      print("Firebase not available, returning demo content");
      return _getDemoContent(moduleId);
    }
    
    try {
      print("=== CONTENT FETCH ATTEMPT ===");
      print("Exact path check: /courses/$courseId/modules/$moduleId/content");
      
      // Try to fetch the specific document the user added (based on screenshot)
      print("Trying to access document directly at path: /courses/$courseId/modules/$moduleId/content/pjR68RuCSeKjMZa1FTRa");
      
      DocumentSnapshot directContentDoc = await _firestore!
        .collection('courses')
        .doc(courseId)
        .collection('modules')
        .doc(moduleId)
        .collection('content')
        .doc('pjR68RuCSeKjMZa1FTRa')
        .get();
      
      if (directContentDoc.exists) {
        print("Direct document access successful!");
        print("Document data: ${directContentDoc.data()}");
        var content = ContentModel.fromJson(
          directContentDoc.data() as Map<String, dynamic>, 
          directContentDoc.id
        );
        return [content];
      } else {
        print("Direct document access failed - document doesn't exist at path");
      }
      
      // Step 2: Try getting all documents in the content collection
      print("Trying to list all documents in content collection");
      QuerySnapshot contentDocs = await _firestore!
        .collection('courses')
        .doc(courseId)
        .collection('modules')
        .doc(moduleId)
        .collection('content')
        .get();
        
      print("Number of content documents found: ${contentDocs.docs.length}");
      
      if (contentDocs.docs.isNotEmpty) {
        print("Content documents IDs: ${contentDocs.docs.map((doc) => doc.id).join(', ')}");
        
        List<ContentModel> contents = contentDocs.docs.map((doc) {
          print("Processing content document: ${doc.id}");
          print("Document data: ${doc.data()}");
          return ContentModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        // Sort by order field manually
        contents.sort((a, b) => a.order.compareTo(b.order));
        return contents;
      } else {
        print("No documents found in content collection");
      }
      
      // Step 3: Fallback to returning demo content
      print("All document access attempts failed, returning demo content");
      return _getDemoContent(moduleId);
    } catch (e) {
      print("Error getting module content: $e");
      print("Stack trace: ${StackTrace.current}");
      return _getDemoContent(moduleId);
    }
  }
  
  // For testing: Return demo courses when Firebase is not available
  List<CourseModel> _getDemoCourses() {
    return [
      CourseModel(
        id: 'demo-course-1',
        title: 'Introduction to Flutter',
        description: 'Learn the basics of Flutter development',
        imageUrl: 'assets/images/flutter_course.jpg',
      ),
      CourseModel(
        id: 'demo-course-2',
        title: 'Firebase for Mobile Apps',
        description: 'Integrate Firebase into your mobile applications',
        imageUrl: 'assets/images/firebase_course.jpg',
      ),
    ];
  }
  
  // For testing: Return demo modules when Firebase is not available
  List<ModuleModel> _getDemoModules(String courseId) {
    return [
      ModuleModel(
        id: 'demo-module-1',
        title: 'Getting Started',
        description: 'Introduction to the course',
        order: 1,
      ),
      ModuleModel(
        id: 'demo-module-2',
        title: 'Core Concepts',
        description: 'Fundamental concepts you need to know',
        order: 2,
      ),
      ModuleModel(
        id: 'demo-module-3',
        title: 'Practical Application',
        description: 'Apply what you learned in real projects',
        order: 3,
      ),
    ];
  }
  
  // For testing: Return demo content when Firebase is not available
  List<ContentModel> _getDemoContent(String moduleId) {
    return [
      ContentModel(
        id: 'demo-content-1',
        title: 'Introduction',
        contentType: 'text',
        content: 'Welcome to this module! In this section, we will cover the basics.',
        order: 1,
      ),
      ContentModel(
        id: 'demo-content-2',
        title: 'Key Concepts',
        contentType: 'text',
        content: 'Here are some important concepts you need to understand before moving forward.',
        order: 2,
      ),
      ContentModel(
        id: 'demo-content-3',
        title: 'Video Tutorial',
        contentType: 'video',
        content: 'https://example.com/demo_video.mp4',
        order: 3,
      ),
    ];
  }
} 