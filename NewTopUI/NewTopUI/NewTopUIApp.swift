import AppKit
import SwiftUI

@main
struct NewTopUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitorController: MonitorPanelController?

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let controller = MonitorPanelController()
        monitorController = controller
        controller.installMenuBarItem()
    }

    func applicationWillTerminate(_: Notification) {
        monitorController?.stop()
    }
}

private final class DraggablePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class MonitorPanelController: NSObject {
    private let model = ResourceMonitorModel()
    private let panel: NSPanel
    private var statusItem: NSStatusItem?
    private var hasPositionedPanel = false

    override init() {
        let panel = DraggablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 494),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        super.init()

        let rootView = ContentView(
            model: model,
            onClose: { [weak self] in self?.hide() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        let hostingController = NSHostingController(rootView: rootView)
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        panel.setContentSize(fittingSize)
    }

    func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "System Pulse")
        button.image?.isTemplate = true
        button.toolTip = "System Pulse"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    func stop() {
        model.stop()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showContextMenu(relativeTo: sender)
        } else if panel.isVisible {
            hide()
        } else {
            show(relativeTo: sender)
        }
    }

    @objc private func toggleFromMenu() {
        if panel.isVisible {
            hide()
        } else if let button = statusItem?.button {
            show(relativeTo: button)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func show(relativeTo button: NSStatusBarButton) {
        if !hasPositionedPanel, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.frame)
            let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let panelSize = panel.frame.size
            let idealX = buttonFrame.midX - panelSize.width / 2
            let x = min(max(idealX, screenFrame.minX + 8), screenFrame.maxX - panelSize.width - 8)
            let y = min(buttonFrame.minY - panelSize.height - 8, screenFrame.maxY - panelSize.height - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: max(y, screenFrame.minY + 8)))
            hasPositionedPanel = true
        }

        model.start()
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        panel.orderOut(nil)
        model.stop()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: panel.isVisible ? "Hide System Pulse" : "Show System Pulse", action: #selector(toggleFromMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit System Pulse", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
    }
}
