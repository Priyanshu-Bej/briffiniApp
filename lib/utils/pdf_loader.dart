import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'logger.dart';

class PDFLoader {
  static Future<String?> loadPDF(String url) async {
    try {
      Logger.i("PDFLoader: Loading PDF from URL: $url");
      Logger.i("PDFLoader: Platform: ${Platform.operatingSystem}");

      if (url.isEmpty) {
        Logger.w("PDFLoader: URL is empty");
        return null;
      }

      if (!url.startsWith('http')) {
        Logger.w("PDFLoader: Invalid URL format, must start with http: $url");
        return null;
      }

      Logger.i("PDFLoader: Making HTTP request...");
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            Duration(seconds: 60),
            onTimeout: () {
              Logger.w("PDFLoader: HTTP request timed out after 60 seconds");
              throw Exception('Connection timed out. Please try again.');
            },
          );

      Logger.i("PDFLoader: Response status code: ${response.statusCode}");
      Logger.d("PDFLoader: Response headers: ${response.headers}");

      if (response.statusCode == 200) {
        Logger.i(
          "PDFLoader: Download successful, content size: ${response.bodyBytes.length} bytes",
        );

        // Verify that this is likely a PDF by checking first few bytes
        if (response.bodyBytes.length > 5) {
          List<int> header = response.bodyBytes.sublist(0, 5);
          String headerStr = String.fromCharCodes(header);
          if (!headerStr.startsWith('%PDF')) {
            Logger.w(
              "PDFLoader: WARNING - Content does not start with %PDF signature",
            );
            Logger.w("PDFLoader: First 5 bytes: $headerStr");
          }
        }

        try {
          final dir = await getTemporaryDirectory();
          Logger.d("PDFLoader: Using temp directory: ${dir.path}");

          // Create a subdirectory for PDFs if not exists
          final pdfDir = Directory('${dir.path}/pdf_cache');
          if (!await pdfDir.exists()) {
            try {
              await pdfDir.create(recursive: true);
              Logger.d("PDFLoader: Created cache directory: ${pdfDir.path}");
            } catch (e) {
              Logger.e("PDFLoader: Failed to create cache directory: $e");
              // Fall back to using temp directory directly
              final filePath =
                  '${dir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf';
              final file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);
              Logger.i("PDFLoader: File written to temp directory: $filePath");
              return filePath;
            }
          }

          // Add timestamp to avoid cache issues
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${pdfDir.path}/document_$timestamp.pdf';

          final file = File(filePath);
          try {
            await file.writeAsBytes(response.bodyBytes);
          } catch (e) {
            Logger.e("PDFLoader: Failed to write file: $e");
            // Try to clean up and retry with a different filename
            try {
              if (await file.exists()) {
                await file.delete();
              }
              // Retry with a different filename
              final retryPath =
                  '${pdfDir.path}/document_retry_${DateTime.now().millisecondsSinceEpoch}.pdf';
              final retryFile = File(retryPath);
              await retryFile.writeAsBytes(response.bodyBytes);
              Logger.i("PDFLoader: File written on retry: $retryPath");
              return retryPath;
            } catch (retryError) {
              Logger.e("PDFLoader: Retry failed: $retryError");
              return null;
            }
          }

          Logger.i("PDFLoader: File written to disk at: $filePath");
          Logger.d("PDFLoader: File size: ${await file.length()} bytes");

          // Verify file exists and is readable
          if (await file.exists()) {
            final fileSize = await file.length();
            Logger.d("PDFLoader: File size after writing: $fileSize bytes");

            if (fileSize == 0) {
              Logger.e("PDFLoader: ERROR - File has zero size");
              return null;
            }

            // Try to read the first few bytes to verify access and check PDF signature
            try {
              final bytes = await file.openRead(0, 10).first;
              final headerStr = String.fromCharCodes(bytes);
              Logger.d("PDFLoader: File header: $headerStr");

              if (!headerStr.startsWith('%PDF')) {
                Logger.w(
                  "PDFLoader: WARNING - File does not start with PDF signature",
                );
                Logger.w("PDFLoader: First 10 bytes: $headerStr");
                // Continue anyway as the file may still be a PDF with different encoding
              }

              Logger.i(
                "PDFLoader: Successfully read ${bytes.length} bytes from file",
              );

              return filePath;
            } catch (e) {
              Logger.e("PDFLoader: Error reading file: $e");
              Logger.e("PDFLoader: Stack trace: ${StackTrace.current}");
              return null;
            }
          } else {
            Logger.e("PDFLoader: ERROR - File does not exist after writing");
            return null;
          }
        } catch (e) {
          Logger.e("PDFLoader: Error writing file: $e");
          Logger.e("PDFLoader: Stack trace: ${StackTrace.current}");
          return null;
        }
      } else {
        Logger.e("PDFLoader: HTTP error: ${response.statusCode}");
        if (response.body.isNotEmpty) {
          Logger.e(
            "PDFLoader: Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...",
          );
        }
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('PDFLoader: Error: $e');
      Logger.e('PDFLoader: Stack trace: ${StackTrace.current}');
      return null;
    }
  }
}
