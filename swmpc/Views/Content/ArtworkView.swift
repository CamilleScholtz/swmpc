//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    #if os(iOS)
        @Binding var image: UIImage?
    #elseif os(macOS)
        @Binding var image: NSImage?
    #endif

    var body: some View {
        if let image {
            #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            #endif
        } else {
            Rectangle()
                .fill(Color(.secondarySystemFill).opacity(0.3))
                .aspectRatio(contentMode: .fit)
                .scaledToFill()
        }
    }
}
