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
        print(
          "Found ${modulesSnapshot.docs.length} modules in modules collection",
        );
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
      print("Fetching content for module ID: $moduleId in course: $courseId");
      List<ContentModel> allContents = [];

      // First verify module exists and is published
      print("Verifying module access...");
      DocumentSnapshot moduleDoc =
          await _firestore!.collection('modules').doc(moduleId).get();

      if (!moduleDoc.exists) {
        print("Module $moduleId does not exist");
        return [];
      }

      final moduleData = moduleDoc.data() as Map<String, dynamic>;
      if (moduleData['courseId'] != courseId) {
        print("Module $moduleId does not belong to course $courseId");
        return [];
      }

      if (moduleData['isPublished'] != true) {
        print("Module $moduleId is not published");
        return [];
      }

      print("Module access verified. Reading content...");

      // First try to read inline content from the module document itself
      try {
        print("Trying to read inline content from module document");
        if (moduleData.containsKey('content')) {
          print("Found inline content in module document");
          final content = moduleData['content'] as Map<String, dynamic>;

          // Handle videos
          if (content.containsKey('videos')) {
            print("Processing inline videos");
            final videos = content['videos'] as List;
            for (var video in videos) {
              if (video is Map) {
                print("Processing video: $video");
                // Ensure video URL is properly formatted
                String videoUrl = video['url'] ?? video['content'] ?? '';
                if (videoUrl.isNotEmpty) {
                  print("Found video URL: $videoUrl");
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
                  print("Warning: Empty video URL in video data: $video");
                }
              }
            }
          }

          // Handle PDFs
          if (content.containsKey('pdfs')) {
            print("Processing inline PDFs");
            final pdfs = content['pdfs'] as List;
            for (var pdf in pdfs) {
              if (pdf is Map) {
                print("Processing PDF: $pdf");
                String pdfUrl = pdf['url'] ?? pdf['content'] ?? '';
                if (pdfUrl.isNotEmpty) {
                  print("Found PDF URL: $pdfUrl");
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
                  print("Warning: Empty PDF URL in PDF data: $pdf");
                }
              }
            }
          }

          // Handle notes
          if (content.containsKey('notes')) {
            print("Processing inline notes");
            if (content['notes'] is List) {
              final notes = content['notes'] as List;
              for (var note in notes) {
                if (note is Map) {
                  print("Processing note: $note");
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
              print("Processing single note text");
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
        print("Error reading inline content: $e");
        print("Stack trace: ${StackTrace.current}");
      }

      // If no inline content found, try the subcollections (keeping existing logic as fallback)
      if (allContents.isEmpty) {
        print("No inline content found, checking subcollections...");
        // First try the direct content collection under the module
        try {
          print("Trying direct content collection under module");
          QuerySnapshot contentDocs =
              await _firestore!
                  .collection('modules')
                  .doc(moduleId)
                  .collection('content')
                  .get();

          print("Direct content docs found: ${contentDocs.docs.length}");
          for (var doc in contentDocs.docs) {
            print("Processing content: ${doc.id} - Data: ${doc.data()}");
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            allContents.add(ContentModel.fromJson(data, doc.id));
          }
        } catch (e) {
          print("Error accessing direct content collection: $e");
        }

        // If no content found, try the videos and pdfs collections
        if (allContents.isEmpty) {
          try {
            print("Trying videos collection");
            QuerySnapshot videosDocs =
                await _firestore!
                    .collection('modules')
                    .doc(moduleId)
                    .collection('videos')
                    .get();

            print("Videos found: ${videosDocs.docs.length}");
            for (var doc in videosDocs.docs) {
              print("Processing video: ${doc.id} - Data: ${doc.data()}");
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['type'] = 'video';
              allContents.add(ContentModel.fromJson(data, doc.id));
            }
          } catch (e) {
            print("Error accessing videos collection: $e");
          }

          try {
            print("Trying pdfs collection");
            QuerySnapshot pdfsDocs =
                await _firestore!
                    .collection('modules')
                    .doc(moduleId)
                    .collection('pdfs')
                    .get();

            print("PDFs found: ${pdfsDocs.docs.length}");
            for (var doc in pdfsDocs.docs) {
              print("Processing PDF: ${doc.id} - Data: ${doc.data()}");
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['type'] = 'pdf';
              allContents.add(ContentModel.fromJson(data, doc.id));
            }
          } catch (e) {
            print("Error accessing pdfs collection: $e");
          }
        }

        // If still no content, try the top-level content collection
        if (allContents.isEmpty) {
          try {
            print("Trying top-level content collection");
            QuerySnapshot topLevelContentDocs =
                await _firestore!
                    .collection('content')
                    .where('moduleId', isEqualTo: moduleId)
                    .get();

            print(
              "Top-level content found: ${topLevelContentDocs.docs.length}",
            );
            for (var doc in topLevelContentDocs.docs) {
              print(
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
            print("Error accessing top-level content: $e");
          }
        }
      }

      // If we found content, validate URLs and return sorted
      if (allContents.isNotEmpty) {
        print("\nContent validation and summary:");
        print("Total content items found: ${allContents.length}");

        // Validate and log each content item
        for (var content in allContents) {
          print("\nContent Item:");
          print("- ID: ${content.id}");
          print("- Type: ${content.contentType}");
          print("- Title: ${content.title}");
          print("- URL/Content: ${content.content}");

          if (content.contentType == 'video' || content.contentType == 'pdf') {
            if (!content.content.startsWith('http')) {
              print(
                "WARNING: Invalid URL format for ${content.contentType}: ${content.content}",
              );
            }
          }
        }

        // Sort by order
        allContents.sort((a, b) => a.order.compareTo(b.order));
        return allContents;
      }

      print("No content found for module $moduleId after trying all paths");
      return [];
    } catch (e) {
      print("Error getting module content: $e");
      print("Stack trace: ${StackTrace.current}");
      throw e;
    }
  }
}
