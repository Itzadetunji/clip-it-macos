//
//  AboutView.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI

struct AboutView: View {
    let year = Date.now.formatted(.dateTime.year())
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("ClipIt")
                    .font(SofiaFont.ultraLight(size: 64))
                VStack(alignment: .leading, spacing: 2) {
                    Text("© \(year) ClipIt. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Saving The Best Moments").font(
                        SofiaFont.light(size: 12)
                    )
                }
                Spacer()
            }
            
            HStack {
                Link(
                    destination: URL(string: "https://get-clip-it.vercel.app/")!
                ) {
                    Text("Home Page")
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(.tertiary)
                .cornerRadius(6)
                .font(.callout)

                Link(
                    destination: URL(
                        string: "https://github.com/itzadetunji/clip-it-macos"
                    )!
                ) {
                    Text("Github")
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(.tertiary)
                .cornerRadius(6)
                .font(.callout)

                Link(destination: URL(string: "https://github.com/itzadetunji/clip-it-macos/graphs/contributors")!) {
                    Text("Contributors")
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(.tertiary)
                .cornerRadius(6)
                .font(.callout)
            }

        }

    }
}

#Preview {
    AboutView()
}
