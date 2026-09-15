import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Non-secret client config. Cloudinary cloud name + unsigned preset are safe
/// to ship in client code by design (that's what an unsigned preset is for);
/// the API key/secret used for signed uploads live only in the backend's .env.
class AppConfig {
  static const int _backendPort = 5050;

  /// Android emulators can't reach the host machine via `localhost`; they use
  /// the special alias 10.0.2.2 instead. Real devices need the host's LAN IP
  /// here — update this if running on physical hardware.
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://localhost:$_backendPort/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_backendPort/api';
    return 'http://localhost:$_backendPort/api';
  }

  static const String cloudinaryCloudName = 'dfpy4bdh0';
  static const String cloudinaryUnsignedPreset = 'mcq_portal_unsigned';
}
