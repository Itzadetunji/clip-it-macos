//
//  ContentView.swift
//  clip it mac
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI

struct ClipIt: View {
    @State var currentTab: NavbarTab = NavbarTab.general
    @State var homeViewModel: HomeViewModel = HomeViewModel()

    var body: some View {
        VStack {
            NavBar(currentTab: $currentTab)

            Spacer()

            Group {
                switch currentTab {
                case .general: HomeView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: currentTab)
            .onAppear {
                homeViewModel.retrieveUser()
            }
        }
        .padding()
        .frame(width: 450, height: 200)
    }
}

#Preview {
    ClipIt()
}
