//
//  HomeView.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI

struct HomeView: View {
    @State var launchOnLogin: Bool = false
    var body: some View {
        preferenceRow(label: "Startup") {
            Toggle("Launch on Login", isOn: $launchOnLogin)
                .toggleStyle(.checkbox)
        }
    }
}

private let labelColumnWidth: CGFloat = 120
private func preferenceRow<Content: View>(
    label: String,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack {
        Text(label)
            .foregroundStyle(.secondary)
            .frame(width: labelColumnWidth, alignment: .trailing)

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView()
}
