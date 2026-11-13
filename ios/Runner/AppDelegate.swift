import AVFoundation
import CoreLocation
import Flutter
import PDFKit
import UIKit

/// 与 Android 端 MainActivity.kt 对应的 iOS 实现：
///  timeline/audio    语音播放（AVAudioPlayer）
///  timeline/media    视频时长 / 首帧缩略图（AVFoundation）
///  timeline/file     PDF 页数 / 逐页渲染（PDFKit）
///  timeline/location 当前位置 + 反查省市（CoreLocation + CLGeocoder）
///  timeline/nav      唤起导航 App（高德 / 百度 / 苹果地图）
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var audioChannel: FlutterMethodChannel?
  private let locationBridge = LocationBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 用注册表拿到 binaryMessenger（SceneDelegate 模板下 AppDelegate 的 window 不一定可用）
    // 注意：registrar(forPlugin:) 返回可选值，必须先解包
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TimelineNative") else {
      NSLog("TimelineNative: 拿不到 plugin registrar，原生通道未注册")
      return
    }
    registerChannels(messenger: registrar.messenger())
  }

  // MARK: - Channels

  private func registerChannels(messenger: FlutterBinaryMessenger) {
    registerAudio(messenger: messenger)
    registerMedia(messenger: messenger)
    registerFile(messenger: messenger)
    registerLocation(messenger: messenger)
    registerNavigation(messenger: messenger)
  }

  private func registerAudio(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "timeline/audio", binaryMessenger: messenger)
    audioChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "play":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
          result(FlutterError(code: "ARG", message: "path is empty", details: nil))
          return
        }
        do {
          self?.stopAudio()
          let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
          player.delegate = self
          player.prepareToPlay()
          player.play()
          self?.audioPlayer = player
          result(true)
        } catch {
          self?.stopAudio()
          result(FlutterError(code: "PLAY", message: error.localizedDescription, details: nil))
        }
      case "stop":
        self?.stopAudio()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func stopAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
  }

  private func registerMedia(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "timeline/media", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "ARG", message: "path is empty", details: nil))
        return
      }
      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "MEDIA", message: "file not found", details: nil))
        return
      }
      switch call.method {
      case "duration":
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        let ms = seconds.isFinite ? Int(seconds * 1000) : 0
        result(ms)
      case "thumb":
        let width = args["width"] as? Int ?? 320
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: CGFloat(width) * 2, height: CGFloat(width) * 2)
        do {
          let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
          let image = UIImage(cgImage: cgImage)
          let targetWidth = CGFloat(width)
          let targetHeight = image.size.height / max(image.size.width, 1) * targetWidth
          let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetWidth, height: max(targetHeight, 1)))
          let scaled = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
          }
          if let data = scaled.pngData() {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(nil)
          }
        } catch {
          result(FlutterError(code: "MEDIA", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerFile(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "timeline/file", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "ARG", message: "path is empty", details: nil))
        return
      }
      guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
        result(FlutterError(code: "PDF", message: "无法打开这个 PDF（可能已加密或损坏）", details: nil))
        return
      }
      switch call.method {
      case "pdfPages":
        result(document.pageCount)
      case "pdfRender":
        let index = args["index"] as? Int ?? 0
        let width = args["width"] as? Int ?? 1000
        guard index >= 0 && index < document.pageCount, let page = document.page(at: index) else {
          result(FlutterError(code: "INDEX", message: "page out of range", details: nil))
          return
        }
        let box = page.bounds(for: .mediaBox)
        let scale = CGFloat(width) / max(box.width, 1)
        let size = CGSize(width: CGFloat(width), height: max(box.height * scale, 1))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
          UIColor.white.setFill()
          context.fill(CGRect(origin: .zero, size: size))
          context.cgContext.translateBy(x: 0, y: size.height)
          context.cgContext.scaleBy(x: scale, y: -scale)
          page.draw(with: .mediaBox, to: context.cgContext)
        }
        if let data = image.pngData() {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerLocation(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "timeline/location", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "current" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.locationBridge.request(result)
    }
  }

  private func registerNavigation(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "timeline/nav", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let lat = args?["lat"] as? Double ?? 0
      let lng = args?["lng"] as? Double ?? 0
      let name = args?["name"] as? String ?? "目的地"
      let hasPoint = !(lat == 0 && lng == 0)
      let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
      var candidates: [String] = []
      if hasPoint {
        candidates.append("iosamap://viewMap?sourceApplication=timeline&poiname=\(encoded)&lat=\(lat)&lon=\(lng)&dev=0")
        candidates.append("baidumap://map/marker?location=\(lat),\(lng)&title=\(encoded)&content=\(encoded)&src=ios.timeline")
        candidates.append("https://maps.apple.com/?ll=\(lat),\(lng)&q=\(encoded)")
      } else {
        candidates.append("iosamap://poi?sourceApplication=timeline&keywords=\(encoded)&dev=0")
        candidates.append("baidumap://map/place/search?query=\(encoded)&src=ios.timeline")
        candidates.append("https://maps.apple.com/?q=\(encoded)")
      }
      AppDelegate.openFirstAvailable(candidates, index: 0, result: result)
    }
  }

  private static func openFirstAvailable(
    _ candidates: [String], index: Int, result: @escaping FlutterResult
  ) {
    guard index < candidates.count else {
      result(false)
      return
    }
    guard let url = URL(string: candidates[index]) else {
      openFirstAvailable(candidates, index: index + 1, result: result)
      return
    }
    UIApplication.shared.open(url, options: [:]) { success in
      if success {
        result(true)
      } else {
        openFirstAvailable(candidates, index: index + 1, result: result)
      }
    }
  }
}

// MARK: - AVAudioPlayerDelegate

extension AppDelegate: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    audioChannel?.invokeMethod("completed", arguments: nil)
    stopAudio()
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    audioChannel?.invokeMethod("completed", arguments: nil)
    stopAudio()
  }
}

// MARK: - 定位

final class LocationBridge: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var pendingResult: FlutterResult?
  private var finished = false

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func request(_ result: @escaping FlutterResult) {
    pendingResult = result
    finished = false
    switch manager.authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .denied, .restricted:
      finishWithError(code: "PERM", message: "用户拒绝了定位权限")
    default:
      manager.requestLocation()
    }
  }

  private func finishWithError(code: String, message: String) {
    guard !finished, let result = pendingResult else { return }
    finished = true
    pendingResult = nil
    result(FlutterError(code: code, message: message, details: nil))
  }

  private func finishWithLocation(_ location: CLLocation) {
    guard !finished, let result = pendingResult else { return }
    finished = true
    pendingResult = nil
    let lat = location.coordinate.latitude
    let lng = location.coordinate.longitude
    CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) {
      [weak self] placemarks, _ in
      _ = self
      var province = ""
      var city = ""
      if let mark = placemarks?.first {
        province = mark.administrativeArea ?? ""
        city = mark.locality ?? (mark.subAdministrativeArea ?? "")
      }
      if province.isEmpty && city.isEmpty {
        province = "当前位置"
      }
      result(["lat": lat, "lng": lng, "province": province, "city": city])
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard pendingResult != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      finishWithError(code: "PERM", message: "用户拒绝了定位权限")
    default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.last {
      finishWithLocation(location)
    } else {
      finishWithError(code: "LOC", message: "暂时拿不到当前位置")
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finishWithError(code: "LOC", message: "暂时拿不到当前位置，请稍后重试或手动填写")
  }
}
