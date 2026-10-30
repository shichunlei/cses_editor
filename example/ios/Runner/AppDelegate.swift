import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "JournalImageShare") {
      JournalImageShare.register(with: registrar.messenger())
    }
  }
}


/// 图片分享的 iOS 宿主适配器；系统面板中由用户选择微信或朋友圈，关闭后释放图片。
final class JournalImageShare {
  /// 使用当前 engine 的 messenger 注册，无账号、SDK AppID 或进程级服务。
  static func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "cses.offline/journal_image_share", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "shareImage" else { result(FlutterMethodNotImplemented); return }
        guard let args = call.arguments as? [String: Any],
              let data = args["png"] as? FlutterStandardTypedData,
              let image = UIImage(data: data.data) else {
          result(FlutterError(code: "invalid", message: "分享图片无效", details: nil)); return
        }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
          result(FlutterError(code: "unavailable", message: "无法打开系统分享面板", details: nil)); return
        }
        while let next = presenter.presentedViewController { presenter = next }
        let sheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY, width: 1, height: 1)
        sheet.completionWithItemsHandler = { _, completed, _, _ in result(completed) }
        presenter.present(sheet, animated: true)
      }
  }
}
