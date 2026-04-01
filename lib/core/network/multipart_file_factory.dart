import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class MultipartFileFactory {
  const MultipartFileFactory._();

  static Future<MultipartFile> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final filename = _resolveFilename(file);
    return MultipartFile.fromBytes(bytes, filename: filename);
  }

  static String _resolveFilename(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;

    final path = file.path;
    if (path.isEmpty) return 'arquivo.jpg';
    final normalized = path.replaceAll('\\', '/');
    final segment = normalized.split('/').last.trim();
    return segment.isNotEmpty ? segment : 'arquivo.jpg';
  }
}
