import Flutter
import UIKit
import CircleProgrammableWalletSDK

private let CIRCLE_ENDPOINT = "https://enduser-sdk.circle.com/v1/w3s"

public class CircleWalletPlugin: NSObject, FlutterPlugin {

    private let adapter = WalletSdkAdapter()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "circle_wallet_ios",
            binaryMessenger: registrar.messenger()
        )
        let instance = CircleWalletPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "getPlatformName":
            result("iOS")

        case "execute":
            handleExecute(call, result: result)

        default:
            result(nil)
        }
    }

    private func handleExecute(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "BAD_ARGS", message: "Expected map arguments", details: nil))
            return
        }

        let appId = args["appId"] as! String
        let userToken = args["userToken"] as! String
        let encryptionKey = args["encryptionKey"] as! String
        let challengeId = args["challengeId"] as! String
        let enableBiometricsPin = args["enableBiometricsPin"] as? Bool ?? false

        do {
            try configureSDK(appId: appId, enableBiometricsPin: enableBiometricsPin)
        } catch let apiError as ApiError {
            result(FlutterError(
                code: "CONFIG_ERROR",
                message: apiError.displayString,
                details: apiError.errorCode.rawValue
            ))
            return
        } catch {
            result(FlutterError(
                code: "CONFIG_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
            return
        }

        WalletSdk.shared.execute(
            userToken: userToken,
            encryptionKey: encryptionKey,
            challengeIds: [challengeId]
        ) { response in
            switch response.result {
            case .success(let execResult):
                var payload: [String: Any] = [
                    "status": execResult.status.rawValue,
                    "resultType": execResult.resultType.rawValue
                ]
                if let data = execResult.data {
                    if let signature = data.signature { payload["signature"] = signature }
                    if let signedTransaction = data.signedTransaction { payload["signedTransaction"] = signedTransaction }
                    if let txHash = data.txHash { payload["txHash"] = txHash }
                }
                result(payload)

            case .failure(let error):
                result(FlutterError(
                    code: "EXECUTE_ERROR",
                    message: error.displayString,
                    details: error.errorCode.rawValue
                ))
            }
        }
    }

    private func configureSDK(appId: String, enableBiometricsPin: Bool) throws {
        try adapter.ensureConfigured(endPoint: CIRCLE_ENDPOINT, appId: appId, enableBiometricsPin: enableBiometricsPin)
    }
}
