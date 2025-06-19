import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;

class PDFLoader {
  static Future<String?> loadPDF(String url) async {
    try {
      print("PDFLoader: Loading PDF from URL: $url");
      print("PDFLoader: Platform: ${Platform.operatingSystem}");
      
      if (url.isEmpty) {
        print("PDFLoader: URL is empty");
        return null;
      }
      
      if (!url.startsWith('http')) {
        print("PDFLoader: Invalid URL format, must start with http: $url");
        return null;
      }
      
      print("PDFLoader: Making HTTP request...");
      final response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 60), onTimeout: () {
        print("PDFLoader: HTTP request timed out after 60 seconds");
        throw Exception('Connection timed out. Please try again.');
      });

      print("PDFLoader: Response status code: ${response.statusCode}");
      print("PDFLoader: Response headers: ${response.headers}");
      
      if (response.statusCode == 200) {
        print("PDFLoader: Download successful, content size: ${response.bodyBytes.length} bytes");

        // Verify that this is likely a PDF by checking first few bytes
        if (response.bodyBytes.length > 5) {
          List<int> header = response.bodyBytes.sublist(0, 5);
          String headerStr = String.fromCharCodes(header);
          if (!headerStr.startsWith('%PDF')) {
            print("PDFLoader: WARNING - Content does not start with %PDF signature");
            print("PDFLoader: First 5 bytes: $headerStr");
          }
        }

        try {
          final dir = await getTemporaryDirectory();
          print("PDFLoader: Using temp directory: ${dir.path}");
          
          // Create a subdirectory for PDFs if not exists
          final pdfDir = Directory('${dir.path}/pdf_cache');
          if (!await pdfDir.exists()) {
            await pdfDir.create(recursive: true);
          }
          
          // Add timestamp to avoid cache issues
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${pdfDir.path}/document_$timestamp.pdf';
          
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          print("PDFLoader: File written to disk at: $filePath");
          print("PDFLoader: File size: ${await file.length()} bytes");
          
          // Verify file exists and is readable
          if (await file.exists()) {
            final fileSize = await file.length();
            print("PDFLoader: File size after writing: $fileSize bytes");
            
            if (fileSize == 0) {
              print("PDFLoader: ERROR - File has zero size");
              return null;
            }
            
            // Try to read the first few bytes to verify access and check PDF signature
            try {
              final bytes = await file.openRead(0, 10).first;
              final headerStr = String.fromCharCodes(bytes);
              print("PDFLoader: File header: $headerStr");
              
              if (!headerStr.startsWith('%PDF')) {
                print("PDFLoader: WARNING - File does not start with PDF signature");
                print("PDFLoader: First 10 bytes: $headerStr");
                // Continue anyway as the file may still be a PDF with different encoding
              }
              
              print("PDFLoader: Successfully read ${bytes.length} bytes from file");
              
              return filePath;
            } catch (e) {
              print("PDFLoader: Error reading file: $e");
              print("PDFLoader: Stack trace: ${StackTrace.current}");
              return null;
            }
          } else {
            print("PDFLoader: ERROR - File does not exist after writing");
            return null;
          }
        } catch (e) {
          print("PDFLoader: Error writing file: $e");
          print("PDFLoader: Stack trace: ${StackTrace.current}");
          return null;
        }
      } else {
        print("PDFLoader: HTTP error: ${response.statusCode}");
        if (response.body.isNotEmpty) {
          print("PDFLoader: Response body: ${response.body.substring(0, 
              response.body.length > 100 ? 100 : response.body.length)}...");
        }
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('PDFLoader: Error: $e');
      print('PDFLoader: Stack trace: ${StackTrace.current}');
      return null;
    }
  }
}
