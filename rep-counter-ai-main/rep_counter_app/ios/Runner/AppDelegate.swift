import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let videoFrameQueue = DispatchQueue(
    label: "rep_counter.video_frames",
    qos: .userInitiated
  )
  private var cachedVideoPath: String?
  private var cachedMaxWidth: CGFloat = 0
  private var cachedFrameGenerator: AVAssetImageGenerator?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "RepCounterVideoFrames"
    ) else {
      return
    }

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

      self.videoFrameQueue.async {
        do {
          let generator: AVAssetImageGenerator
          if
            self.cachedVideoPath == path,
            abs(self.cachedMaxWidth - maxWidth) < 0.5,
            let cached = self.cachedFrameGenerator
          {
            generator = cached
          } else {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let fresh = AVAssetImageGenerator(asset: asset)
            fresh.appliesPreferredTrackTransform = true
            fresh.maximumSize = CGSize(width: maxWidth, height: maxWidth * 3)
            self.cachedVideoPath = path
            self.cachedMaxWidth = maxWidth
            self.cachedFrameGenerator = fresh
            generator = fresh
          }

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
