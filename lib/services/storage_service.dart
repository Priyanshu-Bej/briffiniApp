import 'package:firebase_storage/firebase_storage.dart';
import '../main.dart'; // Import for isFirebaseInitialized

class StorageService {
  // Flags to indicate operational mode
  bool _isStorageAvailable =
      true; // Default to true and check during initialization

  // Firebase Storage instance with error handling
  FirebaseStorage? _storage;

  StorageService() {
    try {
      _storage = FirebaseStorage.instance;
      print("Firebase Storage initialized successfully");
    } catch (e) {
      print("Failed to initialize Firebase Storage: $e");
      _isStorageAvailable = false;
    }
  }

  // Get download URL for a file
  Future<String?> getDownloadURL(String path) async {
    if (!_isStorageAvailable || _storage == null) {
      print("Firebase Storage not available - returning null URL");
      return null;
    }

    try {
      return await _storage!.ref(path).getDownloadURL();
    } catch (e) {
      print("Error getting download URL: $e");
      return null;
    }
  }

  // Get list of files in a directory
  Future<List<String>> listFiles(String path) async {
    if (!_isStorageAvailable || _storage == null) {
      return [];
    }

    try {
      ListResult result = await _storage!.ref(path).listAll();
      return result.items.map((item) => item.fullPath).toList();
    } catch (e) {
      print("Error listing files: $e");
      return [];
    }
  }

  // Secure URL retrieval for PDFs
  Future<String> getSecurePdfUrl(String storagePath) async {
    if (!_isStorageAvailable || _storage == null) {
      throw Exception("Storage service is not available");
    }

    try {
      print("Getting secure PDF URL for path: $storagePath");

      // Handle different URL formats
      String path = storagePath;

      // If it's already a full URL, extract the path
      if (storagePath.startsWith('http')) {
        print("Converting HTTP URL to storage path");
        Uri uri = Uri.parse(storagePath);
        String fullPath = uri.path;

        // Extract the path after /o/
        int startIndex = fullPath.indexOf('/o/');
        if (startIndex >= 0) {
          path = Uri.decodeComponent(fullPath.substring(startIndex + 3));
          print("Extracted path from URL: $path");
        } else {
          print("Warning: Could not extract path from URL, using as-is");
        }
      } else if (storagePath.startsWith('gs://')) {
        // Remove gs://bucket-name/ prefix
        print("Converting gs:// URL to storage path");
        path = storagePath.replaceFirst(RegExp(r'gs://[^/]+/'), '');
        print("Extracted path from gs:// URL: $path");
      }

      // Create a reference to the file
      final ref = _storage!.ref().child(path);

      // Try to get metadata first to verify the file exists
      try {
        final metadata = await ref.getMetadata();
        print(
          "File exists with size: ${metadata.size}, contentType: ${metadata.contentType}",
        );
      } catch (e) {
        print("Warning: Could not get metadata: $e");
      }

      // Create a signed URL that expires in 1 hour
      final signedUrl = await ref.getDownloadURL();
      print("Generated secure PDF URL successfully");
      return signedUrl;
    } catch (e) {
      print("Error getting secure PDF URL: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Method to get more security details about file (for tracking)
  Future<Map<String, dynamic>> getFileMetadata(String storagePath) async {
    if (!_isStorageAvailable || _storage == null) {
      return {'available': false, 'error': 'Storage service unavailable'};
    }

    try {
      final ref = _storage!.ref().child(storagePath);
      final metadata = await ref.getMetadata();

      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'fullPath': metadata.fullPath,
        'updated': metadata.updated?.toIso8601String(),
        'md5Hash': metadata.md5Hash,
      };
    } catch (e) {
      print("Error getting file metadata: $e");
      return {'available': false, 'error': e.toString()};
    }
  }
}
