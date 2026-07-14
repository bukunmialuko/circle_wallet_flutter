import Foundation
import UIKit
import CircleProgrammableWalletSDK

final class WalletSdkAdapter: NSObject {

    private var didSetProviders = false
    private var lastConfigKey: String?

    func ensureConfigured(endPoint: String, appId: String, enableBiometricsPin: Bool) throws {
        let trimmedAppId = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(endPoint)|\(trimmedAppId)|\(enableBiometricsPin)"

        if !didSetProviders {
            PopoverPresentationCrashGuard.install()

            WalletSdk.shared.setLayoutProvider(self)
            WalletSdk.shared.setErrorMessenger(self)
            WalletSdk.shared.setDelegate(self)
            
            // Set global tint appearance for ALL navigation items (Back, Cancel, Done)
            // to White for visibility on our dark theme.
            DispatchQueue.main.async {
                UINavigationBar.appearance().tintColor = .white
                UIBarButtonItem.appearance().tintColor = .white
            }
            
            didSetProviders = true
        }

        if lastConfigKey != key {
            let settings = WalletSdk.SettingsManagement(
                enableBiometricsPin: enableBiometricsPin
            )
            let configuration = WalletSdk.Configuration(
                endPoint: endPoint,
                appId: trimmedAppId,
                settingsManagement: settings
            )
            try WalletSdk.shared.setConfiguration(configuration)
            lastConfigKey = key
        }
    }
}

extension WalletSdkAdapter: WalletSdkLayoutProvider {

    func securityQuestions() -> [SecurityQuestion] {
        return [
            SecurityQuestion(title: "What is your father’s middle name?", inputType: .text),
            SecurityQuestion(title: "What is your favorite sports team?", inputType: .text),
            SecurityQuestion(title: "What is your mother’s maiden name?", inputType: .text),
            SecurityQuestion(title: "What is the name of your first pet?", inputType: .text),
            SecurityQuestion(title: "What is the name of the city you were born in?", inputType: .text),
            SecurityQuestion(title: "What is the name of the first street you lived on?", inputType: .text),
            SecurityQuestion(title: "When is your father’s birthday?", inputType: .datePicker)
        ]
    }

    func securityQuestionsRequiredCount() -> Int { 2 }

    func securityConfirmItems() -> [SecurityConfirmItem] {
        return [
            SecurityConfirmItem(
                image: makeNumberedCircleImage(number: 1),
                text: "This is the only way to recover my account access."
            ),
            SecurityConfirmItem(
                image: makeNumberedCircleImage(number: 2),
                text: "Owego won’t store my answers so it’s my responsibility to remember them."
            ),
            SecurityConfirmItem(
                image: makeNumberedCircleImage(number: 3),
                text: "I will lose access to my wallet and my digital assets if I forget my answers."
            )
        ]
    }

    /// Creates a numbered circle image for security confirmation items.
    /// Circle: #9E9FA0, Number: #6172F3
    private func makeNumberedCircleImage(number: Int) -> UIImage {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            // Draw Circle (#1C2126 - inactive button background)
            let circleColor = UIColor(hex: "#1C2126")
            circleColor.setFill()
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.fill()

            // Draw Number (#6172F3)
            let numberColor = UIColor(hex: "#6172F3")
            let text = "\(number)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "OpenRunde-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: numberColor
            ]
            let stringSize = text.size(withAttributes: attributes)
            let rect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            text.draw(in: rect, withAttributes: attributes)
        }
    }

    func themeFont() -> ThemeConfig.ThemeFont? {
        return ThemeConfig.ThemeFont(
            regular: "OpenRunde-Regular",
            medium: "OpenRunde-Medium",
            semibold: "OpenRunde-Semibold",
            bold: "OpenRunde-Bold"
        )
    }

    // Brand colour palette mirroring the Android resource overrides
    private enum BrandColor {
        static let background   = UIColor(hex: "#0D0F11")
        static let surface      = UIColor(hex: "#161A1E")
        static let accent       = UIColor(hex: "#6172F3")
        static let primaryText  = UIColor.white
        static let secondaryText = UIColor(hex: "#9E9FA0")
        static let buttonBg     = UIColor(hex: "#FCFCFD")
        static let buttonText   = UIColor.black
        static let inputFill    = UIColor(hex: "#1C2126")
        static let border       = UIColor(hex: "#252A30")
    }

    func imageStore() -> ImageStore {
        // PIN visibility toggle icons (D6, D7)
        let showPin = UIImage(systemName: "eye")?.withTintColor(.white, renderingMode: .alwaysOriginal) ?? UIImage()
        let hidePin = UIImage(systemName: "eye.slash")?.withTintColor(.white, renderingMode: .alwaysOriginal) ?? UIImage()

        // Dropdown chevron (D8)
        let dropdownArrow = UIImage(systemName: "chevron.down")?.withTintColor(.white, renderingMode: .alwaysOriginal) ?? UIImage()

        // Toolbar: back arrow (D10) and close button (D11)
        // Scaled to 34x34 for an optimal balance of visibility and aesthetics.
        let toolbarSize = CGSize(width: 34, height: 34)
        let naviBack = loadIcon(named: "pw_icon_back").resized(to: toolbarSize)
        let naviClose = loadIcon(named: "pw_icon_close").resized(to: toolbarSize)

        // Hero images: Owego logo for security intro (D1) and confirm (D5) screens.
        let owegoLogo = loadIcon(named: "owego_logo", fallback: makeOwegoLogoImage())

        return ImageStore(local: [
            .showPin: showPin,
            .hidePin: hidePin,
            .dropdownArrow: dropdownArrow,
            .naviBack: naviBack,
            .naviClose: naviClose,
            .securityIntroMain: owegoLogo,
            .securityConfirmMain: owegoLogo
        ], remote: [:])
    }

    /// Loads an icon from the SDK's resource bundle, falling back to the main app bundle.
    private func loadIcon(named name: String, fallback: UIImage? = nil) -> UIImage {
        // 1. Try the SDK's own resource bundle (circle_wallet_ios.bundle)
        if let bundleURL = Bundle(for: WalletSdkAdapter.self)
            .url(forResource: "circle_wallet_ios", withExtension: "bundle"),
           let sdkBundle = Bundle(url: bundleURL),
           let image = UIImage(named: name, in: sdkBundle, compatibleWith: nil) {
            return image
        }
        // 2. Try main app bundle
        if let image = UIImage(named: name) {
            return image
        }
        // 3. Fallback
        return fallback ?? UIImage()
    }

    /// Programmatically draws a simplified Owego logo as a fallback.
    private func makeOwegoLogoImage() -> UIImage {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            // Outer circle
            let lineWidth: CGFloat = 8
            UIColor.white.setStroke()
            UIColor.clear.setFill()
            let outerPath = UIBezierPath(ovalIn: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            outerPath.lineWidth = lineWidth
            outerPath.stroke()

            // Left crescent arc
            let crescentPath = UIBezierPath()
            crescentPath.addArc(withCenter: CGPoint(x: 48, y: 60),
                                radius: 30, startAngle: -.pi / 2,
                                endAngle: .pi / 2, clockwise: true)
            crescentPath.addArc(withCenter: CGPoint(x: 60, y: 60),
                                radius: 18, startAngle: .pi / 2,
                                endAngle: -.pi / 2, clockwise: false)
            crescentPath.close()
            UIColor.white.setFill()
            crescentPath.fill()

            // Right leaf/eye shape
            let leafPath = UIBezierPath()
            leafPath.move(to: CGPoint(x: 84, y: 60))
            leafPath.addCurve(to: CGPoint(x: 72, y: 44),
                              controlPoint1: CGPoint(x: 84, y: 52),
                              controlPoint2: CGPoint(x: 80, y: 44))
            leafPath.addCurve(to: CGPoint(x: 60, y: 60),
                              controlPoint1: CGPoint(x: 64, y: 44),
                              controlPoint2: CGPoint(x: 60, y: 52))
            leafPath.addCurve(to: CGPoint(x: 72, y: 76),
                              controlPoint1: CGPoint(x: 60, y: 68),
                              controlPoint2: CGPoint(x: 64, y: 76))
            leafPath.addCurve(to: CGPoint(x: 84, y: 60),
                              controlPoint1: CGPoint(x: 80, y: 76),
                              controlPoint2: CGPoint(x: 84, y: 68))
            leafPath.close()
            leafPath.fill()
        }
    }

    func displayDateFormat() -> String { "yyyy/MM/dd" }
}

extension WalletSdkAdapter: ErrorMessenger {
    func getErrorString(_ code: ApiError.ErrorCode) -> String? { nil }
}

extension WalletSdkAdapter: WalletSdkDelegate {

    func walletSdk(willPresentController controller: UIViewController) {
        // SDK handles its own presentation but we can adjust appearance here
        DispatchQueue.main.async {
            // Refined check: handle both direct and Navigation controllers
            let contentVC = (controller as? UINavigationController)?.topViewController ?? controller
            if let pinVC = contentVC as? BasePINInputViewController {
                pinVC.forgotPINButton.isHidden = true
            }
            
            let nav = controller.navigationController ?? (controller as? UINavigationController)
            nav?.navigationBar.tintColor = .white
            
            // Force the entire app window tint to White while the SDK is active
            UIApplication.shared.windows.first?.tintColor = .white
            
            if #available(iOS 13.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(hex: "#0D0F11")
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                nav?.navigationBar.standardAppearance = appearance
                nav?.navigationBar.scrollEdgeAppearance = appearance
                nav?.navigationBar.compactAppearance = appearance
            }
        }
    }

    func walletSdk(controller: UIViewController, onForgetPINButtonSelected onSelect: Void) {
        DispatchQueue.main.async {
            controller.dismiss(animated: true)
        }
    }

    func walletSdk(controller: UIViewController, onSendAgainButtonSelected onSelect: Void) {
        DispatchQueue.main.async {
            controller.dismiss(animated: true)
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension UIColor {
    convenience init(hex: String, defaultColor: UIColor = .white) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(cgColor: defaultColor.cgColor)
            return
        }
        if hexSanitized.count == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            self.init(cgColor: defaultColor.cgColor)
        }
    }
}
