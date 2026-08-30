import UIKit
import Flutter

class SceneDelegate: FlutterSceneDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    // 1. 冷启动流程（包含 session 与 connectionOptions 参数）
    override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // 获取 FlutterViewController 并挂载 EventChannel
        if let windowScene = scene as? UIWindowScene,
        let controller = windowScene.windows.first?.rootViewController as? FlutterViewController {
            let eventChannel = FlutterEventChannel(
                name: "com.youngl.ylmusic/file_stream",
                binaryMessenger: controller.binaryMessenger
            )
            eventChannel.setStreamHandler(self)
        }

        // 处理冷启动时传入的文件 URL
        if let url = connectionOptions.urlContexts.first?.url {
            handleOpenUrl(url)
        }
    }

    // 2. 热唤醒流程（App 在后台运行时传入文件 URL，类型必须为 UIOpenURLContext）
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleOpenUrl(url)
        }
    }

    // 安全读取外部安全作用域文件并复制到 tmp 目录
    private func handleOpenUrl(_ url: URL) {
        let startAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if startAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let targetUrl = tempDir.appendingPathComponent(url.lastPathComponent)

            if FileManager.default.fileExists(atPath: targetUrl.path) {
                try FileManager.default.removeItem(at: targetUrl)
            }

            try FileManager.default.copyItem(at: url, to: targetUrl)

            if let sink = eventSink {
                sink(targetUrl.path)
            }
        } catch {
            print("Failed to copy security-scoped file: \(error)")
            if let sink = eventSink {
                sink(url.path)
            }
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
