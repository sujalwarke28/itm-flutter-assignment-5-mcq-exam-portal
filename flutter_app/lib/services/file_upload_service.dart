import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'cloudinary_service.dart';

/// Orchestrates the profile-picture flow: pick from the device, upload
/// directly to Cloudinary, then ask the backend to persist the reference on
/// the user's Firestore doc (and clean up their previous image).
class FileUploadService {
  final CloudinaryService _cloudinary;
  final ApiService _api;
  final ImagePicker _picker;

  FileUploadService({CloudinaryService? cloudinary, ApiService? api, ImagePicker? picker})
      : _cloudinary = cloudinary ?? CloudinaryService(),
        _api = api ?? ApiService(),
        _picker = picker ?? ImagePicker();

  Future<String?> pickAndUploadProfilePicture() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;

    final uploaded = await _cloudinary.uploadProfileImage(picked.path);
    await _api.post('/student/upload-profile', body: {
      'imageUrl': uploaded.url,
      'publicId': uploaded.publicId,
    });
    return uploaded.url;
  }
}
