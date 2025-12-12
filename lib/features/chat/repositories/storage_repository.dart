import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Завантаження зображення (для аватарок профілю)
  Future<String> uploadImage({
    required XFile image,
    required String path,
  }) async {
    try {
      final Uint8List imageBytes = await image.readAsBytes();

      final ref = _storage.ref().child(path);

      final String contentType = image.mimeType ?? 'image/jpeg';
      final metadata = SettableMetadata(contentType: contentType);

      final uploadTask = await ref.putData(imageBytes, metadata);

      return await uploadTask.ref.getDownloadURL();
      
    } catch (e) {
      print("Storage Upload Error: $e");
      throw Exception('Image upload failed: $e');
    }
  }
}