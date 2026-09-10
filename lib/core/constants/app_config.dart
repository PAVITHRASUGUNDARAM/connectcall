/// Fill these after creating Firebase + Agora projects.
/// Prefer `--dart-define` so secrets stay out of git:
/// flutter run --dart-define=AGORA_APP_ID=xxx
class AppConfig {
  AppConfig._();

  static const agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '',
  );

  /// Optional static token for assignment testing. Never commit a token.
  static const agoraToken = String.fromEnvironment(
    'AGORA_TOKEN',
    defaultValue: '',
  );

  static const callRingTimeout = Duration(seconds: 45);
  static const callAliveTimeout = Duration(seconds: 45);
  static const callAliveHeartbeat = Duration(seconds: 10);
  static const presenceTtl = Duration(seconds: 90);
  static const presenceHeartbeat = Duration(seconds: 20);
  static const splashDelay = Duration(milliseconds: 1400);

  static bool get isAgoraConfigured => agoraAppId.isNotEmpty;
}

class FirestorePaths {
  FirestorePaths._();
  static const users = 'users';
  static const calls = 'calls';
  static const userDevices = 'userDevices';
  static const deviceTokens = 'tokens';
}
