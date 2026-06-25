import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Ensure window is visible and comes to front
    self.makeKeyAndOrderFront(nil)
    self.isOpaque = true
    self.backgroundColor = NSColor.white
    NSApp.activate(ignoringOtherApps: true)
  }
}
