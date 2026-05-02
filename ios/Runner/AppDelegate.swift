import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "clutch_scenarios/export",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "saveImage" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let args = call.arguments as? [String: Any],
          let data = args["bytes"] as? FlutterStandardTypedData
        else {
          result(false)
          return
        }
        self?.saveImageToPhotos(data: data.data, result: result)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func saveImageToPhotos(data: Data, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization { status in
      let allowed: Bool
      if #available(iOS 14, *) {
        allowed = (status == .authorized || status == .limited)
      } else {
        allowed = (status == .authorized)
      }
      guard allowed else {
        DispatchQueue.main.async {
          result(false)
        }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: data, options: nil)
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          result(success && error == nil)
        }
      })
    }
  }
}
