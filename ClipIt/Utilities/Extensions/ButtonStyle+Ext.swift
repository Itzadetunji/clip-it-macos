//
//  ButtonStyle+Ext.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func glassAltButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
