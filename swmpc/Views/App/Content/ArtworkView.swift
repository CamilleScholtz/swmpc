//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    @Binding var image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        } else {
            Rectangle()
                .fill(Color(.secondarySystemFill).opacity(0.3))
                .aspectRatio(contentMode: .fit)
                .scaledToFill()
        }
    }
}
