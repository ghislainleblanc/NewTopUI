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
    private struct PanelPlacement {
        let screenIdentifier: String
        let relativeOrigin: NSPoint
    }

    private static let panelOriginDefaultsKey = "monitorPanelOrigin"
    private static let panelScreenDefaultsKey = "monitorPanelScreen"
    private static let panelScreenOriginXDefaultsKey = "monitorPanelScreenOriginX"
    private static let panelScreenOriginYDefaultsKey = "monitorPanelScreenOriginY"
    private static let wakeRestorationRetryDelay: TimeInterval = 0.5
    private static let wakeRestorationMaxAttempts = 20
    private static let wakeRestorationRequiredStableAttempts = 3

    private let model = ResourceMonitorModel()
    private let panel: NSPanel
    private var statusItem: NSStatusItem?
    private var hasPositionedPanel = false
    private var placementBeforeSleep: PanelPlacement?
    private var isRestoringAfterWake = false
    private var wakeRestorationStableAttempts = 0
    private var wakeRestorationWorkItem: DispatchWorkItem?

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

        let fittingSize = hostingController.sizeThatFits(
            in: NSSize(width: 420, height: CGFloat.greatestFiniteMagnitude)
        )
        panel.setContentSize(fittingSize)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }
        let iconConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.image = NSImage(
            systemSymbolName: "cpu",
            accessibilityDescription: String(localized: "System Pulse", comment: "App name")
        )?
            .withSymbolConfiguration(iconConfiguration)
        button.image?.isTemplate = true
        button.toolTip = String(localized: "System Pulse", comment: "App name")
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        // macOS realizes status items in a remote scene. Let its initial layout finish
        // before reading the button geometry and presenting another window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak button] in
            guard let self, let button else { return }
            show(relativeTo: button)
        }
    }

    func stop() {
        wakeRestorationWorkItem?.cancel()
        if hasPositionedPanel, !isRestoringAfterWake {
            savePanelPlacement()
        }
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

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? String(localized: "Unknown", comment: "Fallback when the app version cannot be read")
        NSApplication.shared.activate()
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [.applicationVersion: version]
        )
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func panelDidMove(_: Notification) {
        guard !isRestoringAfterWake else {
            return
        }

        savePanelPlacement()
    }

    @objc private func workspaceWillSleep(_: Notification) {
        guard
            !isRestoringAfterWake,
            hasPositionedPanel,
            let placement = currentPanelPlacement()
        else {
            return
        }

        savePanelPlacement()
        placementBeforeSleep = placement
        isRestoringAfterWake = true
        wakeRestorationStableAttempts = 0
        wakeRestorationWorkItem?.cancel()
    }

    @objc private func workspaceDidWake(_: Notification) {
        guard placementBeforeSleep != nil else {
            isRestoringAfterWake = false
            return
        }

        scheduleWakeRestoration(attempt: 0, after: 0.25)
    }

    @objc private func screenParametersDidChange(_: Notification) {
        guard
            isRestoringAfterWake,
            let placement = placementBeforeSleep
        else {
            return
        }

        wakeRestorationStableAttempts = 0
        _ = restorePanelPlacementIfPossible(placement)
    }

    private func savePanelPlacement() {
        let defaults = UserDefaults.standard
        defaults.set(NSStringFromPoint(panel.frame.origin), forKey: Self.panelOriginDefaultsKey)

        guard let placement = currentPanelPlacement() else {
            return
        }

        defaults.set(placement.screenIdentifier, forKey: Self.panelScreenDefaultsKey)
        defaults.set(placement.relativeOrigin.x, forKey: Self.panelScreenOriginXDefaultsKey)
        defaults.set(placement.relativeOrigin.y, forKey: Self.panelScreenOriginYDefaultsKey)
    }

    private func currentPanelPlacement() -> PanelPlacement? {
        guard let screen = panel.screen, let screenIdentifier = screenIdentifier(for: screen) else {
            return nil
        }

        return PanelPlacement(
            screenIdentifier: screenIdentifier,
            relativeOrigin: NSPoint(
                x: panel.frame.minX - screen.frame.minX,
                y: panel.frame.minY - screen.frame.minY
            )
        )
    }

    private func show(relativeTo button: NSStatusBarButton) {
        if !hasPositionedPanel {
            if let savedOrigin = savedPanelOrigin() {
                panel.setFrameOrigin(savedOrigin)
                hasPositionedPanel = true
            } else if let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.frame)
                let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
                let panelSize = panel.frame.size
                let idealX = buttonFrame.midX - panelSize.width / 2
                let x = min(max(idealX, screenFrame.minX + 8), screenFrame.maxX - panelSize.width - 8)
                let y = min(buttonFrame.minY - panelSize.height - 8, screenFrame.maxY - panelSize.height - 8)
                panel.setFrameOrigin(NSPoint(x: x, y: max(y, screenFrame.minY + 8)))
                hasPositionedPanel = true
            }
        }

        model.start()
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func savedPanelOrigin() -> NSPoint? {
        let defaults = UserDefaults.standard

        if let savedScreenIdentifier = defaults.string(forKey: Self.panelScreenDefaultsKey) {
            guard
                let relativeX = defaults.object(forKey: Self.panelScreenOriginXDefaultsKey) as? NSNumber,
                let relativeY = defaults.object(forKey: Self.panelScreenOriginYDefaultsKey) as? NSNumber,
                let origin = origin(
                    for: PanelPlacement(
                        screenIdentifier: savedScreenIdentifier,
                        relativeOrigin: NSPoint(x: relativeX.doubleValue, y: relativeY.doubleValue)
                    )
                )
            else {
                return nil
            }

            return origin
        }

        guard let originString = defaults.string(forKey: Self.panelOriginDefaultsKey) else {
            return nil
        }

        let origin = NSPointFromString(originString)
        let savedFrame = NSRect(origin: origin, size: panel.frame.size)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(savedFrame) }) else {
            return nil
        }

        return origin
    }

    private func scheduleWakeRestoration(attempt: Int, after delay: TimeInterval) {
        wakeRestorationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard
                let self,
                self.isRestoringAfterWake,
                let placement = self.placementBeforeSleep
            else {
                return
            }

            if self.restorePanelPlacementIfPossible(placement) {
                self.wakeRestorationStableAttempts += 1
                if self.wakeRestorationStableAttempts >= Self.wakeRestorationRequiredStableAttempts {
                    self.finishWakeRestoration()
                } else {
                    self.scheduleWakeRestoration(
                        attempt: attempt + 1,
                        after: Self.wakeRestorationRetryDelay
                    )
                }
            } else if attempt < Self.wakeRestorationMaxAttempts {
                self.wakeRestorationStableAttempts = 0
                self.scheduleWakeRestoration(
                    attempt: attempt + 1,
                    after: Self.wakeRestorationRetryDelay
                )
            } else {
                self.finishWakeRestoration()
            }
        }
        wakeRestorationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func restorePanelPlacementIfPossible(_ placement: PanelPlacement) -> Bool {
        guard let origin = origin(for: placement) else {
            return false
        }

        panel.setFrameOrigin(origin)
        hasPositionedPanel = true
        return true
    }

    private func finishWakeRestoration() {
        wakeRestorationWorkItem?.cancel()
        wakeRestorationWorkItem = nil
        placementBeforeSleep = nil
        isRestoringAfterWake = false
        wakeRestorationStableAttempts = 0
    }

    private func origin(for placement: PanelPlacement) -> NSPoint? {
        guard
            let screen = NSScreen.screens.first(where: {
                screenIdentifier(for: $0) == placement.screenIdentifier
            })
        else {
            return nil
        }

        let origin = NSPoint(
            x: screen.frame.minX + placement.relativeOrigin.x,
            y: screen.frame.minY + placement.relativeOrigin.y
        )
        return visibleOrigin(origin, on: screen)
    }

    private func screenIdentifier(for screen: NSScreen) -> String? {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard
            let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber,
            let displayUUID = CGDisplayCreateUUIDFromDisplayID(screenNumber.uint32Value)?.takeRetainedValue()
        else {
            return nil
        }

        return CFUUIDCreateString(nil, displayUUID) as String
    }

    private func visibleOrigin(_ origin: NSPoint, on screen: NSScreen) -> NSPoint {
        let proposedFrame = NSRect(origin: origin, size: panel.frame.size)
        guard !screen.visibleFrame.intersects(proposedFrame) else {
            return origin
        }

        let visibleFrame = screen.visibleFrame
        let x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - panel.frame.width - 8)
        let y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - panel.frame.height - 8)
        return NSPoint(x: x, y: y)
    }

    private func hide() {
        panel.orderOut(nil)
        model.stop()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        let aboutItem = NSMenuItem(
            title: String(localized: "About System Pulse", comment: "Menu item that opens the About panel"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        let visibilityTitle = if panel.isVisible {
            String(localized: "Hide System Pulse", comment: "Menu item that hides the monitor")
        } else {
            String(localized: "Show System Pulse", comment: "Menu item that shows the monitor")
        }
        let showItem = NSMenuItem(
            title: visibilityTitle,
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: String(localized: "Quit System Pulse", comment: "Menu item that quits the app"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
    }
}
