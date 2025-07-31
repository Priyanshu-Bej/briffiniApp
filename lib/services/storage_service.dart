import 'package:firebase_storage/firebase_storage.dart';
import '../utils/logger.dart';
import '../main.dart'; // For FirebaseInitState

class StorageService {
  // Flags to indicate operational mode
  bool _isStorageAvailable =
      true; // Default to true and check during initialization

  // Firebase Storage instance with error handling
  FirebaseStorage? _storage;

  StorageService() {
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    try {
      // Wait for Firebase to be initialized first
      await FirebaseInitState.ensureInitialized();

      _storage = FirebaseStorage.instance;
      _isStorageAvailable = true;
      Logger.i("Firebase Storage initialized successfully");
    } catch (e) {
      Logger.e("Failed to initialize Firebase Storage: $e");
      _isStorageAvailable = false;
      _storage = null;
    }
  }

  // Get download URL for a file
  Future<String?> getDownloadURL(String path) async {
    if (!_isStorageAvailable || _storage == null) {
      Logger.w("Firebase Storage not available - returning null URL");
      return null;
    }

    try {
      return await _storage!.ref(path).getDownloadURL();
    } catch (e) {
      Logger.e("Error getting download URL: $e");
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
      Logger.e("Error listing files: $e");
      return [];
    }
  }

  // Secure URL retrieval for PDFs
  Future<String> getSecurePdfUrl(String storagePath) async {
    if (!_isStorageAvailable || _storage == null) {
      throw Exception("Storage service is not available");
    }

    try {
      Logger.i("Getting secure PDF URL for path: $storagePath");

      // Handle different URL formats
      String path = storagePath;

      // If it's already a full URL, extract the path
      if (storagePath.startsWith('http')) {
        Logger.d("Converting HTTP URL to storage path");
        Uri uri = Uri.parse(storagePath);
        String fullPath = uri.path;

        // Extract the path after /o/
        int startIndex = fullPath.indexOf('/o/');
        if (startIndex >= 0) {
          path = Uri.decodeComponent(fullPath.substring(startIndex + 3));
          Logger.d("Extracted path from URL: $path");
        } else {
          Logger.w("Warning: Could not extract path from URL, using as-is");
        }
      } else if (storagePath.startsWith('gs://')) {
        // Remove gs://bucket-name/ prefix
        Logger.d("Converting gs:// URL to storage path");
        path = storagePath.replaceFirst(RegExp(r'gs://[^/]+/'), '');
        Logger.d("Extracted path from gs:// URL: $path");
      }

      // Create a reference to the file
      final ref = _storage!.ref().child(path);

      // Try to get metadata first to verify the file exists and user has access
      try {
        final metadata = await ref.getMetadata();
        Logger.d(
          "File exists with size: ${metadata.size}, contentType: ${metadata.contentType}",
        );
      } catch (e) {
        if (e is FirebaseException) {
          if (e.code == 'unauthorized' || e.code == 'permission-denied') {
            Logger.w("Permission denied when checking metadata: ${e.message}");
            throw Exception(
              "Access denied (403): You don't have permission to access this file. Please verify your course access.",
            );
          } else if (e.code == 'object-not-found') {
            Logger.w("File not found: ${e.message}");
            throw Exception(
              "File not found (404): The requested PDF file doesn't exist",
            );
          }
        }
        Logger.w("Warning: Could not get metadata: $e");
      }

      // Create a signed URL that expires in 1 hour
      try {
        final signedUrl = await ref.getDownloadURL();
        Logger.i("Generated secure PDF URL successfully");
        return signedUrl;
      } catch (e) {
        if (e is FirebaseException) {
          if (e.code == 'unauthorized' || e.code == 'permission-denied') {
            Logger.w(
              "Permission denied when getting download URL: ${e.message}",
            );
            throw Exception(
              "Access denied (403): You don't have permission to access this file. Please verify your course access.",
            );
          } else if (e.code == 'object-not-found') {
            Logger.w("File not found: ${e.message}");
            throw Exception(
              "File not found (404): The requested PDF file doesn't exist",
            );
          } else {
            Logger.e("Firebase error: ${e.code} - ${e.message}");
            throw Exception("Error accessing file: ${e.message}");
          }
        }
        Logger.e("Unknown error: $e");
        rethrow;
      }
    } catch (e) {
      Logger.e("Error getting secure PDF URL: $e");
      Logger.e("Stack trace: ${StackTrace.current}");
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
      Logger.e("Error getting file metadata: $e");
      return {'available': false, 'error': e.toString()};
    }
  }
}
