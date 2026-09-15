import 'package:cloudinary_public/cloudinary_public.dart';

import '../utils/app_config.dart';

class CloudinaryUploadResult {
  final String url;
  final String publicId;
  const CloudinaryUploadResult({required this.url, required this.publicId});
}

/// Thin wrapper around the unsigned Cloudinary upload used for direct,
/// client-side uploads (profile pictures). Signed uploads (Excel sheets,
/// result PDFs, exam-report exports) happen server-side instead, since they
/// require the API secret, which must never ship in client code.
class CloudinaryService {
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    AppConfig.cloudinaryCloudName,
    AppConfig.cloudinaryUnsignedPreset,
    cache: false,
  );

  Future<CloudinaryUploadResult> uploadProfileImage(String filePath) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        filePath,
        folder: 'mcq-portal/profiles',
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return CloudinaryUploadResult(url: response.secureUrl, publicId: response.publicId);
  }
}
