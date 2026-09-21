import AppKit
import SwiftUI

/// Keeps AppKit presentation operations out of SwiftUI's view-update transaction.
struct ProcessDetailsPopover<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.scheduleUpdate(from: self, anchor: view)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.invalidate()
    }

    final class Coordinator: NSObject, NSPopoverDelegate {
        private let popover = NSPopover()
        private var host: NSHostingController<Content>?
        private var pendingUpdate: DispatchWorkItem?
        private var presentation: Binding<Bool>?
        private var isInvalidated = false
        private var isClosing = false

        override init() {
            super.init()
            popover.animates = false
            popover.behavior = .transient
            popover.delegate = self
        }

        func scheduleUpdate(from source: ProcessDetailsPopover, anchor: NSView) {
            pendingUpdate?.cancel()
            presentation = source.$isPresented
            let work = DispatchWorkItem { [weak self, weak anchor] in
                guard let self, let anchor, !isInvalidated, !isClosing else { return }
                apply(source, anchor: anchor)
            }
            pendingUpdate = work
            DispatchQueue.main.async(execute: work)
        }

        func invalidate() {
            isInvalidated = true
            pendingUpdate?.cancel()
            presentation = nil
            // Dismantling can itself occur during a SwiftUI commit.
            DispatchQueue.main.async { [self] in
                popover.delegate = nil
                popover.close()
                popover.contentViewController = nil
                host = nil
            }
        }

        func popoverWillClose(_ notification: Notification) {
            isClosing = true
            pendingUpdate?.cancel()
        }

        func popoverDidClose(_ notification: Notification) {
            // Never release the hosting view or mutate SwiftUI state inside AppKit's close callback.
            DispatchQueue.main.async { [weak self] in
                guard let self, !isInvalidated else { return }
                popover.contentViewController = nil
                host = nil
                presentation?.wrappedValue = false
                isClosing = false
            }
        }
    }
}

private extension ProcessDetailsPopover.Coordinator {
    func apply(_ source: ProcessDetailsPopover<Content>, anchor: NSView) {
        guard source.isPresented else {
            if popover.isShown { popover.close() }
            return
        }
        guard anchor.window != nil else { return }

        if let host {
            host.rootView = source.content()
        } else {
            let controller = NSHostingController(rootView: source.content())
            controller.sizingOptions = []
            host = controller
            popover.contentViewController = controller
            popover.contentSize = NSSize(width: 440, height: 580)
        }
        if !popover.isShown {
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
        }
    }
}
