import 'package:circle_wallet_platform_interface/src/method_channel_circle_wallet.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// {@template circle_wallet_platform}
/// The interface that implementations of circle_wallet must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `CircleWallet`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added [CircleWalletPlatform] methods.
/// {@endtemplate}
abstract class CircleWalletPlatform extends PlatformInterface {
  /// {@macro circle_wallet_platform}
  CircleWalletPlatform() : super(token: _token);

  static final Object _token = Object();

  static CircleWalletPlatform _instance = MethodChannelCircleWallet();

  /// The default instance of [CircleWalletPlatform] to use.
  ///
  /// Defaults to [MethodChannelCircleWallet].
  static CircleWalletPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [CircleWalletPlatform] when they register themselves.
  static set instance(CircleWalletPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Return the current platform name.
  Future<String?> getPlatformName();

  /// Runs a Circle challenge and returns the result of challenge execution.
  ///
  /// The returned map may contain:
  /// - `status`: the challenge's terminal status (e.g. `COMPLETE`, `FAILED`).
  /// - `resultType`: the type of challenge that was executed.
  /// - `signature`: present for signing challenges.
  /// - `signedTransaction`: present for signing challenges.
  /// - `txHash`: the on-chain transaction hash, present only for transaction
  ///   (transfer) challenges.
  ///
  /// Every field beyond `status`/`resultType` is optional: a key is absent,
  /// or its value is `null`, whenever the SDK did not populate it for that
  /// challenge type. `txHash` in particular is only ever meaningful for
  /// transaction challenges — do not expect it for signing-only challenges.
  ///
  /// UNVERIFIED: whether `txHash` becomes available as soon as the
  /// transaction is submitted, or only once it is confirmed on chain, has
  /// not been established against a live challenge. Until this is verified,
  /// do not treat the presence of `txHash` as proof of on-chain confirmation.
  Future<Map<String, dynamic>> execute({
    required String appId,
    required String userToken,
    required String encryptionKey,
    required String challengeId,
    bool enableBiometricsPin = false,
  });

  /// A stream that emits whenever the user taps "Forgot PIN?" inside the
  /// SDK UI. Listen to this stream to start the PIN-restore flow.
  ///
  /// Default implementation returns an empty stream. Android overrides this.
  Stream<void> get forgotPinStream => const Stream.empty();
}
