import 'package:circle_wallet_platform_interface/circle_wallet_platform_interface.dart';

CircleWalletPlatform get _platform => CircleWalletPlatform.instance;

/// Returns the name of the current platform.
Future<String> getPlatformName() async {
  final platformName = await _platform.getPlatformName();
  if (platformName == null) throw Exception('Unable to get platform name.');
  return platformName;
}

/// Runs a Circle challenge and returns its result.
///
/// See [CircleWalletPlatform.execute] for the shape of the returned map and
/// which fields are optional.
Future<Map<String, dynamic>> execute({
  required String appId,
  required String userToken,
  required String encryptionKey,
  required String challengeId,
  bool enableBiometricsPin = false,
}) {
  return CircleWalletPlatform.instance.execute(
    appId: appId,
    userToken: userToken,
    encryptionKey: encryptionKey,
    challengeId: challengeId,
    enableBiometricsPin: enableBiometricsPin,
  );
}

/// A stream that emits when the user taps "Forgot PIN?" in the SDK UI.
///
/// Listen to this stream to initiate the PIN-restore flow:
///   1. Call your backend's `POST /user/pin/restore` to obtain a restore
///      challenge ID.
///   2. Call [execute] with that challenge ID to let the user set a new PIN.
Stream<void> get forgotPinStream => _platform.forgotPinStream;
