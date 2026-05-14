//
//  Keyboard+Ext.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let saveClip = Self(
        "saveClip",
        default: .init(.c, modifiers: [.control, .option])
    )
}
