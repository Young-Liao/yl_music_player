import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var queuedFiles: [String] = []

    override func applicationWillFinishLaunching(_ notification: Notification) {
        super.applicationWillFinishLaunching(notification)

        // Register handler for kAEOpenDocuments (Finder double-click, drag-to-dock, `open` command)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

        // Setup EventChannel to stream file paths directly to Dart in real-time
        let eventChannel = FlutterEventChannel(
            name: "com.youngl.ylmusic/file_stream",
            binaryMessenger: controller.engine.binaryMessenger
        )
        eventChannel.setStreamHandler(self)

        super.applicationDidFinishLaunching(aNotification)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Standard NSApplication delegate fallback
    override func application(_ sender: NSApplication, openFiles filenames: [String]) {
        sendFilesToFlutter(filenames)
    }

    // AppleEvent Interceptor
    @objc private func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let fileList = event.paramDescriptor(forKeyword: keyDirectObject) else { return }

        var paths: [String] = []
        for i in 1...fileList.numberOfItems {
            if let path = fileList.atIndex(i)?.stringValue {
                if path.hasPrefix("file://"), let url = URL(string: path) {
                    paths.append(url.path)
                } else {
                    paths.append(path)
                }
            }
        }

        if !paths.isEmpty {
            sendFilesToFlutter(paths)
        }
    }

    private func sendFilesToFlutter(_ files: [String]) {
        if let sink = eventSink {
            sink(files)
        } else {
            queuedFiles.append(contentsOf: files)
        }
    }

    // MARK: - FlutterStreamHandler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Drain any files received during startup
        if !queuedFiles.isEmpty {
            events(queuedFiles)
            queuedFiles.removeAll()
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
