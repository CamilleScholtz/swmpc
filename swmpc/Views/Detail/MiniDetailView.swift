//
//  MiniDetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 5/8/2025.
//

//import SwiftUI
//
enum PlayerMatchedGeometry {
    case artwork
}
//
//struct CompactNowPlaying: View {
//    @Environment(MPD.self) private var mpd
//    @Binding var expanded: Bool
//    var hideArtworkOnExpanded: Bool = true
//    var animationNamespace: Namespace.ID
//
//    private var title: String {
//        mpd.status.song?.title ?? "Not Playing"
//    }
//
//    private var artist: String? {
//        mpd.status.song?.artist
//    }
//
//    private var playPauseButtonType: ButtonType {
//        mpd.status.isPlaying ? .pause : .play
//    }
//
//    var body: some View {
//        HStack(spacing: 8) {
//            artwork
//                .frame(width: 40, height: 40)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(title)
//                    .lineLimit(1)
//                    .font(.headline)
//                    .foregroundColor(.primary)
//
//                if let artist {
//                    Text(artist)
//                        .lineLimit(1)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//            }
//            .padding(.trailing, -18)
//
//            Spacer(minLength: 0)
//
//            Button {
//                Task {
//                    try await ConnectionManager.command().pause(mpd.status.isPlaying)
//                }
//            } label: {
//                Image(systemName: mpd.status.isPlaying ? "pause.fill" : "play.fill")
//                    .font(.system(size: 20))
//                    .frame(width: 44, height: 44)
//                    .contentShape(Rectangle())
//            }
//            .buttonStyle(.plain)
//
//            Button {
//                Task {
//                    try await ConnectionManager.command().next()
//                }
//            } label: {
//                Image(systemName: "forward.fill")
//                    .font(.system(size: 20))
//                    .frame(width: 44, height: 44)
//                    .contentShape(Rectangle())
//            }
//            .buttonStyle(.plain)
//        }
//        .padding(.horizontal, 8)
//        .frame(height: 56)
//        .background(.regularMaterial)
//        .clipShape(RoundedRectangle(cornerRadius: 10))
//        .contentShape(.rect)
//        .transformEffect(.identity)
//        .onTapGesture {
//            withAnimation(.playerExpandAnimation) {
//                expanded = true
//            }
//        }
//    }
//
//    @ViewBuilder
//    private var artwork: some View {
////        if !hideArtworkOnExpanded || !expanded {
////            if let artwork = mpd.status.song?.artwork {
////                AsyncImage(url: artwork) { phase in
////                    if let image = phase.image {
////                        image
////                            .resizable()
////                            .aspectRatio(contentMode: .fill)
////                    } else {
////                        Color.gray
////                    }
////                }
////                .background(Color.gray.opacity(0.3))
////                .clipShape(.rect(cornerRadius: 7))
////                .matchedGeometryEffect(
////                    id: PlayerMatchedGeometry.artwork,
////                    in: animationNamespace
////                )
////            } else {
////                RoundedRectangle(cornerRadius: 7)
////                    .fill(Color.gray.opacity(0.3))
////                    .matchedGeometryEffect(
////                        id: PlayerMatchedGeometry.artwork,
////                        in: animationNamespace
////                    )
////            }
////        }
//    }
//}
//
//enum ButtonType {
//    case play
//    case pause
//    case stop
//    case forward
//    case backward
//}
//
//extension Animation {
//    static let playerExpandAnimationDuration: TimeInterval = 0.4
//    static var playerExpandAnimation: Animation {
//        .interpolatingSpring(
//            mass: 1.0,
//            stiffness: 100,
//            damping: 16,
//            initialVelocity: 0
//        )
//    }
//}
