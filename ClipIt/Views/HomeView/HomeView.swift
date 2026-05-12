//
//  HomeView.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI

struct HomeView: View {
    @State var launchOnLogin: Bool = false
    @State var viewModel = HomeViewModel()

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            preferenceRow(label: "Record") {
                HStack {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.userSettings.isRecording },
                            set: { newValue in
                                Task { await viewModel.setRecording(newValue) }
                            }
                        )
                    ) {
                        EmptyView()
                    }
                    .toggleStyle(.switch)

                    if viewModel.userSettings.isRecording {
                        Button {
                            Task { await viewModel.setRecording(false) }
                        } label: {
                            Text("Clip It")
                        }
                        .buttonStyle(.glass)
                        .transition(.opacity)
                    }
                }
                .animation(
                    .easeInOut(duration: 0.15),
                    value: viewModel.userSettings.isRecording
                )
            }

            preferenceRow(label: "Startup") {
                Toggle(
                    "Launch on Login",
                    isOn: $viewModel.userSettings.launchOnLogin
                )
                .toggleStyle(.checkbox)
            }

            //            preferenceRow(label: "Status Bar Icon", alignment: .top) {
            //                VStack(alignment: .leading) {
            //                    Toggle(
            //                        "Hide Status Bar Icon",
            //                        isOn: $viewModel.userSettings.StatusBarIcon
            //                    )
            //                    .toggleStyle(.checkbox)
            //                    Text("Re-run ClipIt again to show the hidden icon")
            //                        .font(.caption)
            //                        .foregroundStyle(.secondary)
            //                }
            //            }

            preferenceRow(label: "Time") {
                HStack(spacing: 16) {
                    Toggle(
                        "15s",
                        isOn: Binding(
                            get: { viewModel.userSettings.Time == .fifteen },
                            set: {
                                if $0 { viewModel.userSettings.Time = .fifteen }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)

                    Toggle(
                        "30s",
                        isOn: Binding(
                            get: { viewModel.userSettings.Time == .thirty },
                            set: {
                                if $0 { viewModel.userSettings.Time = .thirty }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)

                    Toggle(
                        "60s",
                        isOn: Binding(
                            get: { viewModel.userSettings.Time == .sixty },
                            set: {
                                if $0 { viewModel.userSettings.Time = .sixty }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                }.animation(
                    .easeInOut(duration: 0.15),
                    value: viewModel.userSettings.IsCustom
                )
            }.disabled(viewModel.userSettings.IsCustom)

            preferenceRow(label: "Custom Time") {
                HStack(spacing: 16) {
                    Toggle(
                        "Enable",
                        isOn: Binding(
                            get: { viewModel.userSettings.IsCustom },
                            set: {
                                viewModel.userSettings.IsCustom = $0
                            }

                        )
                    )
                    .toggleStyle(.checkbox)

                    TextField(
                        "90",
                        text: Binding<String>(
                            get: {
                                String(viewModel.userSettings.CustomTime)
                            },
                            set: {
                                (newValue: String) in
                                viewModel.userSettings.CustomTime =
                                    Int(newValue) ?? 0
                            }
                        )
                    ).frame(maxWidth: 50).disabled(
                        !viewModel.userSettings.IsCustom
                    )
                }.animation(
                    .easeInOut(duration: 0.15),
                    value: viewModel.userSettings.IsCustom
                )
            }

        }
        .onAppear {
            viewModel.retrieveUser()
        }
        .onChange(of: viewModel.userSettings) { _, _ in
            viewModel.saveChanges()
        }
        .alert(
            item: $viewModel.alertItem
        ) {
            alertItem in
            Alert(
                title: alertItem.title,
                message: alertItem.message,
                dismissButton: alertItem.dismissButton
            )
        }

    }
}

private let labelColumnWidth: CGFloat = 120
private func preferenceRow<Content: View>(
    label: String,
    alignment: VerticalAlignment = .center,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(alignment: alignment, spacing: 18) {
        Text(label)
            .foregroundStyle(.secondary)
            .frame(width: labelColumnWidth, alignment: .trailing)
            .font(.caption)

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView()
}
