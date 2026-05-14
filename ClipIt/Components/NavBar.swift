//
//  NavBar.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI

enum NavbarTab: String, CaseIterable, Identifiable {
    case general = "General"
    case about = "About"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .about: return "person.crop.circle"
        }
    }
}

struct NavBar: View {
    @Binding var currentTab: NavbarTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(NavbarTab.allCases) { tab in
                NavBarButton(tab: tab, currentTab: $currentTab)
            }

        }
    }
}

struct NavBarButton: View {
    var tab: NavbarTab
    @Binding var currentTab: NavbarTab

    private var isSelected: Bool { tab == currentTab }

    var body: some View {
        
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbolName)
                    .font(
                        Font.system(size: 22)
                    )
                    .symbolRenderingMode(.hierarchical)
                Text(tab.rawValue)
                    .font(.caption)
            }

        }
        
        .foregroundStyle(
            isSelected
                ? Color.accentColor : Color(nsColor: .secondaryLabelColor)
        )
        .padding(0)
        .frame(width: 52, height: 52)
        .glassAltButtonStyle()
    }
}

#Preview {
    NavBar(currentTab: .constant(NavbarTab.general))
}
