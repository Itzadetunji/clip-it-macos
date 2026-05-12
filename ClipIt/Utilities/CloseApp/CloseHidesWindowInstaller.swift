//
//  CloseHidesWindowInstaller.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AppKit
import Foundation
import SwiftUI

struct CloseHidesWindowInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }

        func attachIfNeeded(to view: NSView) {
            guard let window = view.window else { return }
            window.delegate = self
        }
    }
}
