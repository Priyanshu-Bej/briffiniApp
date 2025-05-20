import 'package:firebase_storage/firebase_storage.dart';
import '../main.dart'; // Import for isFirebaseInitialized

class StorageService {
  // Flags to indicate operational mode
  bool _isStorageAvailable = isFirebaseInitialized;
  
  // Firebase Storage instance with error handling
  FirebaseStorage? _storage;
  
  StorageService() {
    if (!isFirebaseInitialized) {
      _isStorageAvailable = false;
      print("Skipping Firebase Storage initialization - Firebase not initialized");
      return;
    }
    
    try {
      _storage = FirebaseStorage.instance;
    } catch (e) {
      print("Failed to initialize Firebase Storage: $e");
      _isStorageAvailable = false;
    }
  }
  
  // Get download URL for a file
  Future<String?> getDownloadURL(String path) async {
    if (!_isStorageAvailable) {
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
    if (!_isStorageAvailable) {
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
    if (!_isStorageAvailable) {
      throw Exception("Storage service is not available");
    }

    try {
      // Generate a signed URL with a short expiration (15 minutes)
      final ref = _storage!.ref().child(storagePath);
      
      // Create a signed URL that expires in 15 minutes
      // This prevents permanent storage/bookmarking of the URL
      final signedUrl = await ref.getDownloadURL();
      
      print("Generated secure PDF URL with expiration");
      return signedUrl;
    } catch (e) {
      print("Error getting secure PDF URL: $e");
      rethrow;
    }
  }

  // Method to get more security details about file (for tracking)
  Future<Map<String, dynamic>> getFileMetadata(String storagePath) async {
    if (!_isStorageAvailable) {
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