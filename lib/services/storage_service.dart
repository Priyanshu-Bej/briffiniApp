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
} 