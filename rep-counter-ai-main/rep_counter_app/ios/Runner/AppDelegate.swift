import AVFoundation
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

    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "RepCounterVideoFrames"
    )
    let channel = FlutterMethodChannel(
      name: "rep_counter/video_frames",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "frame" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(
          FlutterError(
            code: "missing_path",
            message: "Video path is required",
            details: nil
          )
        )
        return
      }

      let timeMs = (args["timeMs"] as? NSNumber)?.int64Value ?? 0
      let maxWidth = CGFloat((args["maxWidth"] as? NSNumber)?.doubleValue ?? 480)

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let asset = AVURLAsset(url: URL(fileURLWithPath: path))
          let generator = AVAssetImageGenerator(asset: asset)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: maxWidth, height: maxWidth * 3)

          let time = CMTime(value: timeMs, timescale: 1000)
          var actualTime = CMTime.zero
          let image = try generator.copyCGImage(at: time, actualTime: &actualTime)
          guard
            let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
          else {
            DispatchQueue.main.async { result(nil) }
            return
          }

          let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("repcoach-pose-frame.jpg")
          try data.write(to: output, options: .atomic)

          DispatchQueue.main.async {
            result(output.path)
          }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "frame_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }
    }
  }
}
