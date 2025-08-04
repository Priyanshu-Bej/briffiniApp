import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/module_model.dart';
import '../models/content_model.dart';
import '../utils/logger.dart';
import '../main.dart'; // For FirebaseInitState

class FirestoreService {
  // Flag to indicate operational mode - default to true since we want dynamic data
  bool _isFirestoreAvailable = true;

  // Firebase instance
  FirebaseFirestore? _firestore;

  FirestoreService() {
    _initializeFirestore();
  }

  Future<void> _initializeFirestore() async {
    try {
      // Wait for Firebase to be initialized first
      await FirebaseInitState.ensureInitialized();

      _firestore = FirebaseFirestore.instance;
      _isFirestoreAvailable = true;
      Logger.i("Firestore initialized successfully");
    } catch (e) {
      Logger.e("Failed to initialize Firestore: $e");
      _isFirestoreAvailable = false;
      _firestore = null;
    }
  }

  // Get assigned courses for a user
  Future<List<CourseModel>> getAssignedCourses(List<String> courseIds) async {
    if (!_isFirestoreAvailable || courseIds.isEmpty) {
      Logger.w("Firestore not available or no course IDs provided");
      return [];
    }

    try {
      List<CourseModel> courses = [];

      for (String courseId in courseIds) {
        try {
          DocumentSnapshot courseDoc = await _firestore!
              .collection('courses')
              .doc(courseId)
              .get();

          if (courseDoc.exists) {
            courses.add(
              CourseModel.fromJson(
                courseDoc.data() as Map<String, dynamic>,
                courseDoc.id,
              ),
            );
          }
        } catch (e) {
          Logger.w(
            "Failed to fetch course $courseId: $e - continuing with others",
          );
          // Continue with other courses instead of failing completely
          continue;
        }
      }

      return courses;
    } catch (e) {
      Logger.e("Error getting assigned courses: $e");
      // Check if it's a network connectivity issue
      if (e.toString().contains('Unavailable') ||
          e.toString().contains('Network') ||
          e.toString().contains('connectivity')) {
        Logger.w("Network connectivity issue detected - returning empty list");
        return [];
      }
      rethrow; // Re-throw to handle at UI level
    }
  }

  // Get modules for a course
  Future<List<ModuleModel>> getModules(String courseId) async {
    if (!_isFirestoreAvailable) {
      Logger.w("Firestore not available");
      return [];
    }

    try {
      Logger.i("Fetching modules for course: $courseId");

      // Fetch directly from the top-level modules collection with courseId field
      QuerySnapshot modulesSnapshot = await _firestore!
          .collection('modules')
          .where('courseId', isEqualTo: courseId)
          .orderBy('order', descending: false)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              Logger.w("Modules fetch timeout for course: $courseId");
              throw Exception("Request timeout - please check your connection");
            },
          );

      if (modulesSnapshot.docs.isNotEmpty) {
        Logger.i(
          "Found ${modulesSnapshot.docs.length} modules in modules collection",
        );
        List<ModuleModel> modules = modulesSnapshot.docs.map((doc) {
          Logger.d("Module data: ${doc.data()}");
          return ModuleModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        return modules;
      }

      // No modules found
      Logger.w("No modules found for course $courseId");
      return [];
    } catch (e) {
      Logger.e("Error getting modules: $e");
      rethrow; // Re-throw to handle at UI level
    }
  }

  // Get only published modules for a course (for student view)
  Future<List<ModuleModel>> getPublishedModules(String courseId) async {
    try {
      Logger.i("Fetching published modules for course: $courseId");

      // Fetch directly from modules collection with courseId AND isPublished = true
      QuerySnapshot modulesSnapshot = await _firestore!
          .collection('modules')
          .where('courseId', isEqualTo: courseId)
          .where('isPublished', isEqualTo: true)
          .get();

      if (modulesSnapshot.docs.isNotEmpty) {
        Logger.i("Found ${modulesSnapshot.docs.length} published modules");
        List<ModuleModel> modules = modulesSnapshot.docs.map((doc) {
          Logger.d("Published module data: ${doc.data()}");
          return ModuleModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        // Sort by order field manually
        modules.sort((a, b) => a.order.compareTo(b.order));
        return modules;
      }

      Logger.w("No published modules found for course $courseId");
      return [];
    } catch (e) {
      Logger.e("Error getting published modules: $e");
      rethrow;
    }
  }

  // Get content items for a module
  Future<List<ContentModel>> getModuleContent(
    String courseId,
    String moduleId,
  ) async {
    if (!_isFirestoreAvailable) {
      Logger.w("Firebase not available");
      return [];
    }

    try {
      Logger.i(
        "Fetching content for module ID: $moduleId in course: $courseId",
      );
      List<ContentModel> allContents = [];

      // First verify module exists and is published
      Logger.i("Verifying module access...");
      DocumentSnapshot moduleDoc = await _firestore!
          .collection('modules')
          .doc(moduleId)
          .get();

      if (!moduleDoc.exists) {
        Logger.w("Module $moduleId does not exist");
        return [];
      }

      final moduleData = moduleDoc.data() as Map<String, dynamic>;
      if (moduleData['courseId'] != courseId) {
        Logger.w("Module $moduleId does not belong to course $courseId");
        return [];
      }

      if (moduleData['isPublished'] != true) {
        Logger.w("Module $moduleId is not published");
        return [];
      }

      Logger.i("Module access verified. Reading content...");

      // First try to read inline content from the module document itself
      try {
        Logger.i("Trying to read inline content from module document");
        if (moduleData.containsKey('content')) {
          Logger.i("Found inline content in module document");
          final content = moduleData['content'] as Map<String, dynamic>;

          // Handle videos
          if (content.containsKey('videos')) {
            Logger.i("Processing inline videos");
            final videos = content['videos'] as List;
            for (var video in videos) {
              if (video is Map) {
                Logger.d("Processing video: $video");
                // Ensure video URL is properly formatted
                String videoUrl = video['url'] ?? video['content'] ?? '';
                if (videoUrl.isNotEmpty) {
                  Logger.i("Found video URL: $videoUrl");
                  allContents.add(
                    ContentModel.fromJson(
                      {
                        ...video,
                        'type': 'video',
                        'contentType': 'video',
                        'content': videoUrl,
                      },
                      video['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                    ),
                  );
                } else {
                  Logger.w("Warning: Empty video URL in video data: $video");
                }
              }
            }
          }

          // Handle PDFs
          if (content.containsKey('pdfs')) {
            Logger.i("Processing inline PDFs");
            final pdfs = content['pdfs'] as List;
            for (var pdf in pdfs) {
              if (pdf is Map) {
                Logger.d("Processing PDF: $pdf");
                String pdfUrl = pdf['url'] ?? pdf['content'] ?? '';
                if (pdfUrl.isNotEmpty) {
                  Logger.i("Found PDF URL: $pdfUrl");
                  allContents.add(
                    ContentModel.fromJson(
                      {
                        ...pdf,
                        'type': 'pdf',
                        'contentType': 'pdf',
                        'content': pdfUrl,
                      },
                      pdf['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                    ),
                  );
                } else {
                  Logger.w("Warning: Empty PDF URL in PDF data: $pdf");
                }
              }
            }
          }

          // Handle notes
          if (content.containsKey('notes')) {
            Logger.i("Processing inline notes");
            if (content['notes'] is List) {
              final notes = content['notes'] as List;
              for (var note in notes) {
                if (note is Map) {
                  Logger.d("Processing note: $note");
                  String noteContent = note['content'] ?? note['text'] ?? '';
                  if (noteContent.isNotEmpty) {
                    allContents.add(
                      ContentModel.fromJson(
                        {
                          ...note,
                          'type': 'text',
                          'contentType': 'text',
                          'content': noteContent,
                        },
                        note['id'] ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                      ),
                    );
                  }
                }
              }
            } else if (content['notes'] is String) {
              Logger.i("Processing single note text");
              String noteContent = content['notes'];
              if (noteContent.isNotEmpty) {
                allContents.add(
                  ContentModel.fromJson({
                    'content': noteContent,
                    'type': 'text',
                    'contentType': 'text',
                    'title': 'Notes',
                    'order': 0,
                  }, 'notes'),
                );
              }
            }
          }
        }
      } catch (e) {
        Logger.e("Error reading inline content: $e");
        Logger.d("Stack trace: ${StackTrace.current}");
      }

      // If no inline content found, try the subcollections (keeping existing logic as fallback)
      if (allContents.isEmpty) {
        Logger.i("No inline content found, checking subcollections...");
        // First try the direct content collection under the module
        try {
          Logger.i("Trying direct content collection under module");
          QuerySnapshot contentDocs = await _firestore!
              .collection('modules')
              .doc(moduleId)
              .collection('content')
              .get();

          Logger.i("Direct content docs found: ${contentDocs.docs.length}");
          for (var doc in contentDocs.docs) {
            Logger.d("Processing content: ${doc.id} - Data: ${doc.data()}");
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            allContents.add(ContentModel.fromJson(data, doc.id));
          }
        } catch (e) {
          Logger.e("Error accessing direct content collection: $e");
        }

        // If no content found, try the videos and pdfs collections
        if (allContents.isEmpty) {
          try {
            Logger.i("Trying videos collection");
            QuerySnapshot videosDocs = await _firestore!
                .collection('modules')
                .doc(moduleId)
                .collection('videos')
                .get();

            Logger.i("Videos found: ${videosDocs.docs.length}");
            for (var doc in videosDocs.docs) {
              Logger.d("Processing video: ${doc.id} - Data: ${doc.data()}");
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['type'] = 'video';
              allContents.add(ContentModel.fromJson(data, doc.id));
            }
          } catch (e) {
            Logger.e("Error accessing videos collection: $e");
          }

          try {
            Logger.i("Trying pdfs collection");
            QuerySnapshot pdfsDocs = await _firestore!
                .collection('modules')
                .doc(moduleId)
                .collection('pdfs')
                .get();

            Logger.i("PDFs found: ${pdfsDocs.docs.length}");
            for (var doc in pdfsDocs.docs) {
              Logger.d("Processing PDF: ${doc.id} - Data: ${doc.data()}");
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['type'] = 'pdf';
              allContents.add(ContentModel.fromJson(data, doc.id));
            }
          } catch (e) {
            Logger.e("Error accessing pdfs collection: $e");
          }
        }

        // If still no content, try the top-level content collection
        if (allContents.isEmpty) {
          try {
            Logger.i("Trying top-level content collection");
            QuerySnapshot topLevelContentDocs = await _firestore!
                .collection('content')
                .where('moduleId', isEqualTo: moduleId)
                .get();

            Logger.i(
              "Top-level content found: ${topLevelContentDocs.docs.length}",
            );
            for (var doc in topLevelContentDocs.docs) {
              Logger.d(
                "Processing top-level content: ${doc.id} - Data: ${doc.data()}",
              );
              allContents.add(
                ContentModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              );
            }
          } catch (e) {
            Logger.e("Error accessing top-level content: $e");
          }
        }
      }

      // If we found content, validate URLs and return sorted
      if (allContents.isNotEmpty) {
        Logger.i("\nContent validation and summary:");
        Logger.i("Total content items found: ${allContents.length}");

        // Validate and log each content item
        for (var content in allContents) {
          Logger.d("\nContent Item:");
          Logger.d("- ID: ${content.id}");
          Logger.d("- Type: ${content.contentType}");
          Logger.d("- Title: ${content.title}");
          Logger.d("- URL/Content: ${content.content}");

          if (content.contentType == 'video' || content.contentType == 'pdf') {
            if (!content.content.startsWith('http')) {
              Logger.w(
                "WARNING: Invalid URL format for ${content.contentType}: ${content.content}",
              );
            }
          }
        }

        // Sort by order
        allContents.sort((a, b) => a.order.compareTo(b.order));
        return allContents;
      }

      Logger.w("No content found for module $moduleId after trying all paths");
      return [];
    } catch (e) {
      Logger.e("Error getting module content: $e");
      Logger.d("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }
}
