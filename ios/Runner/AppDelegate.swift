import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let eventChannel = FlutterEventChannel(
                name: "com.youngl.ylmusic/file_stream",
                binaryMessenger: controller.binaryMessenger
            )
            eventChannel.setStreamHandler(self)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // 关键修正：安全读取外部 URL 并复制到本地沙盒
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 1. 请求安全访问权限（针对系统文件/AirDrop 传入的文件）
        let startAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if startAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // 2. 获取 App 本地沙盒 tmp 目录路径
            let tempDir = FileManager.default.temporaryDirectory
            let targetUrl = tempDir.appendingPathComponent(url.lastPathComponent)

            // 如果临时目录已有同名文件，先删除
            if FileManager.default.fileExists(atPath: targetUrl.path) {
                try FileManager.default.removeItem(at: targetUrl)
            }

            // 3. 将外部受保护的文件复制到 App 自由访问的沙盒 tmp 目录
            try FileManager.default.copyItem(at: url, to: targetUrl)

            // 4. 将复制后、具备完全读写权限的【新沙盒路径】传给 Flutter 侧
            if let sink = eventSink {
                sink(targetUrl.path)
            }
            return true
        } catch {
            print("Failed to copy security-scoped file: \(error)")
            // 如果复制失败，退化传递原路径
            if let sink = eventSink {
                sink(url.path)
            }
            return false
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
