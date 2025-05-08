//
//  NowPlayingBackground.swift
//  swmpc
//
//  Created by Camille Scholtz on 5/8/2025.
//

//import SwiftUI
//
//struct NowPlayingBackground: View {
//    let colors: [Color]
//    let expanded: Bool
//    let isFullExpanded: Bool
//    var canBeExpanded: Bool = true
//
//    private var gradientColors: [Color] {
//        if colors.isEmpty {
//            return [.gray, .black]
//        }
//        return colors + [.black]
//    }
//
//    var body: some View {
//        LinearGradient(
//            gradient: Gradient(colors: gradientColors),
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .ignoresSafeArea()
//        .overlay {
//            if expanded, canBeExpanded {
//                Color.black.opacity(0.4)
//                    .ignoresSafeArea()
//            }
//        }
//        .clipShape(
//            RoundedRectangle(
//                cornerRadius: expanded && canBeExpanded ? 0 : 10,
//                style: .continuous
//            )
//        )
//        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 5)
//    }
//}
//
//#Preview {
//    NowPlayingBackground(
//        colors: [.red, .blue],
//        expanded: true,
//        isFullExpanded: true
//    )
//}
