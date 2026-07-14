import ObjectiveC
import UIKit

/// Works around a crash in `CircleProgrammableWalletSDK` 1.4.0.
///
/// The SDK presents its security-question selector ("Select one question") with
/// `modalPresentationStyle = .popover` but never sets `sourceView`/`sourceRect`/`barButtonItem`.
/// UIKit only consults the anchor at regular width, so on iPhone the popover adapts to full screen
/// and the omission is invisible, while on iPad it raises `NSGenericException` from
/// `-[UIPopoverPresentationController presentationTransitionWillBegin]`.
///
/// The SDK ships as a stripped binary and exposes no hook on this path: it calls
/// `setModalPresentationStyle:` and `presentViewController:animated:completion:` back to back with
/// no delegate callback in between, so `WalletSdkDelegate.walletSdk(willPresentController:)` never
/// fires for that controller. Swizzling `present` is the only interception point available.
///
/// The predicate matches only presentations that are certain to throw, so it cannot alter behaviour
/// that already works. The SDK's other popover — the transaction fee tip — sets an anchor and is
/// therefore left alone.
enum PopoverPresentationCrashGuard {

    static func install() {
        _ = installOnce
    }

    private static let installOnce: Void = {
        guard
            let original = class_getInstanceMethod(
                UIViewController.self,
                #selector(UIViewController.present(_:animated:completion:))
            ),
            let replacement = class_getInstanceMethod(
                UIViewController.self,
                #selector(UIViewController.circlepw_present(_:animated:completion:))
            )
        else { return }

        method_exchangeImplementations(original, replacement)
    }()
}

private extension UIViewController {

    @objc
    func circlepw_present(
        _ viewControllerToPresent: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        viewControllerToPresent.circlepw_defuseUnanchoredPopover(presenter: self)

        // Implementations are exchanged, so this dispatches to UIKit's `present`.
        circlepw_present(viewControllerToPresent, animated: animated, completion: completion)
    }

    func circlepw_defuseUnanchoredPopover(presenter: UIViewController) {
        guard
            UIDevice.current.userInterfaceIdiom == .pad,
            modalPresentationStyle == .popover,
            let popover = popoverPresentationController,
            popover.sourceView == nil,
            popover.barButtonItem == nil
        else { return }

        // Anchor as well as restyle. Reading `popoverPresentationController` above instantiates it,
        // and if UIKit were to reuse that instance rather than honour the style change below, an
        // unanchored popover would still throw. Doing both makes either outcome safe.
        if let anchor = presenter.viewIfLoaded {
            popover.sourceView = anchor
            popover.sourceRect = CGRect(
                x: anchor.bounds.midX,
                y: anchor.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        modalPresentationStyle = .formSheet
    }
}
