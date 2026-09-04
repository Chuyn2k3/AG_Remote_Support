import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyBlurView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Privacy Shield: Add dark blur overlay when entering iOS App Switcher
    if let window = self.window, privacyBlurView == nil {
      let blurEffect = UIBlurEffect(style: .dark)
      let blurView = UIVisualEffectView(effect: blurEffect)
      blurView.frame = window.bounds
      blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      blurView.tag = 9999
      window.addSubview(blurView)
      self.privacyBlurView = blurView
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Remove Privacy Shield blur overlay
    if let blurView = self.privacyBlurView {
      UIView.animate(withDuration: 0.15, animations: {
        blurView.alpha = 0
      }) { _ in
        blurView.removeFromSuperview()
        self.privacyBlurView = nil
      }
    }
  }
}
