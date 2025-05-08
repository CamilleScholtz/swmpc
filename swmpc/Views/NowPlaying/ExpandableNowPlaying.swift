//
//  ExpandableNowPlaying.swift
//  swmpc
//
//  Created by Camille Scholtz on 5/8/2025.
//

//import SwiftUI
//
//struct ExpandableNowPlaying: View {
//    @Binding var show: Bool
//    @Binding var expanded: Bool
//    @Environment(MPD.self) private var mpd
//    @State private var draggedOffset: CGFloat = 0.0
//    @State private var mainWindow: UIWindow?
//    @State private var windowProgress: CGFloat = 0.0
//    @State private var progressTrackState: CGFloat = 0.0
//    @State private var expandProgress: CGFloat = 0.0
//    @State private var artwork: PlatformImage?
//    @Namespace private var animationNamespace
//
//    var body: some View {
//        expandableNowPlaying
//            .onAppear {
//                if let window = UIApplication.keyWindow {
//                    mainWindow = window
//                }
//
//                Task {
//                    await fetchArtwork()
//                }
//            }
//            .onChange(of: expanded) {
//                if expanded {
//                    stacked(progress: 1, withAnimation: true)
//                }
//            }
//            .onChange(of: mpd.status.song) {
//                Task {
//                    await fetchArtwork()
//                }
//            }
//            .onPreferenceChange(NowPlayingExpandProgressPreferenceKey.self) { value in
//                expandProgress = value
//            }
//    }
//
//    private func fetchArtwork() async {
//        guard let song = mpd.status.song else {
//            artwork = nil
//            return
//        }
//
//        guard let data = try? await ArtworkManager.shared.get(for: song, shouldCache: false) else {
//            artwork = nil
//            return
//        }
//
//        artwork = PlatformImage(data: data)
//    }
//}
//
//private extension ExpandableNowPlaying {
//    var isFullExpanded: Bool {
//        expandProgress >= 1
//    }
//
//    var expandableNowPlaying: some View {
//        GeometryReader {
//            let size = $0.size
//            let safeArea = $0.safeAreaInsets
//
//            ZStack(alignment: .top) {
//                NowPlayingBackground(
//                    colors: [.primary.opacity(0.6), .secondary.opacity(0.4)],
//                    expanded: expanded,
//                    isFullExpanded: isFullExpanded
//                )
//
//                if expanded {
//                    // Use DetailView for expanded view
//                    DetailView(
//                        artwork: artwork,
//                        isPopupOpen: $expanded,
//                        isMiniplayer: true,
//                        animationNamespace: animationNamespace
//                    )
//                    .opacity(calculateExpandedOpacity())
//                    .padding(.top, 20) // Add space for the dismiss handle
//                } else {
//                    CompactNowPlaying(
//                        expanded: $expanded,
//                        animationNamespace: animationNamespace
//                    )
//                    .opacity(calculateCompactOpacity())
//                }
//
//                if expanded {
//                    // Dismiss handle
//                    Capsule()
//                        .fill(.white.opacity(0.5))
//                        .frame(width: 40, height: 4)
//                        .padding(.top, 10)
//                        .opacity(calculateExpandedOpacity())
//                }
//
//                ProgressTracker(progress: progressTrackState)
//            }
//            .frame(height: expanded ? nil : 56, alignment: .top)
//            .frame(maxHeight: .infinity, alignment: .bottom)
//            .padding(.bottom, expanded ? 0 : safeArea.bottom + 98)
//            .padding(.horizontal, expanded ? 0 : 12)
//            .offset(y: calculateYOffset(in: size))
//            .gesture(
//                DragGesture(minimumDistance: 1.0, coordinateSpace: .local)
//                    .onChanged { value in
//                        draggedOffset = value.translation.height
//
//                        if expanded {
//                            let translation = max(draggedOffset, 0)
//                            let progress = 1 - min(1, translation / (size.height * 0.5))
//                            progressTrackState = progress
//                            stacked(progress: progress, withAnimation: false)
//                        } else {
//                            if draggedOffset < 0 {
//                                let progressFactor = min(1, abs(draggedOffset) / 35)
//                                progressTrackState = progressFactor
//                                stacked(progress: progressFactor, withAnimation: false)
//                            }
//                        }
//                    }
//                    .onEnded { value in
//                        let height = size.height
//                        let velocity = value.predictedEndLocation.y - value.location.y
//                        let velocityFactor = velocity / 15
//                        let totalOffset = draggedOffset + velocityFactor
//
//                        withAnimation(.playerExpandAnimation) {
//                            if expanded {
//                                if totalOffset > height * 0.1 || velocity > 150 {
//                                    expanded = false
//                                    resetStackedWithAnimation()
//                                } else {
//                                    stacked(progress: 1, withAnimation: true)
//                                }
//                            } else {
//                                if totalOffset < -3 || velocity < -50 {
//                                    expanded = true
//                                    stacked(progress: 1, withAnimation: true)
//                                } else {
//                                    stacked(progress: 0, withAnimation: true)
//                                }
//                            }
//                            draggedOffset = 0
//                        }
//                    }
//            )
//            .ignoresSafeArea()
//        }
//    }
//
//    func calculateYOffset(in _: CGSize) -> CGFloat {
//        if expanded {
//            let drag = max(0, draggedOffset)
//            let resistedDrag = pow(drag, 0.9)
//            return resistedDrag
//        } else {
//            let drag = min(0, draggedOffset)
//            let absoluteDrag = abs(drag)
//            let curve = 0.7
//            let easedDrag = pow(absoluteDrag / 80, curve) * 80
//            let maxUpDrag: CGFloat = -160
//            let offset = max(-easedDrag, maxUpDrag)
//            return offset
//        }
//    }
//
//    func stacked(progress: CGFloat, withAnimation: Bool) {
//        if withAnimation {
//            SwiftUI.withAnimation(.playerExpandAnimation) {
//                progressTrackState = progress
//            }
//        } else {
//            progressTrackState = progress
//        }
//
//        mainWindow?.stacked(
//            progress: progress,
//            animationDuration: withAnimation ? Animation.playerExpandAnimationDuration : nil
//        )
//    }
//
//    func resetStackedWithAnimation() {
//        withAnimation(.playerExpandAnimation) {
//            progressTrackState = 0
//        }
//        mainWindow?.resetStackedWithAnimation(duration: Animation.playerExpandAnimationDuration)
//    }
//
//    func calculateCompactOpacity() -> CGFloat {
//        if expanded {
//            let dragProgress = min(1, max(0, draggedOffset) / 80)
//            return dragProgress
//        } else {
//            if draggedOffset < 0 {
//                let progress = min(1, abs(draggedOffset) / 40)
//                let easedProgress = pow(progress, 0.7)
//                return 1 - easedProgress
//            } else {
//                return 1
//            }
//        }
//    }
//
//    func calculateExpandedOpacity() -> CGFloat {
//        if expanded {
//            let dragProgress = min(1, max(0, draggedOffset) / 80)
//            let easedProgress = pow(dragProgress, 0.7)
//            return 1 - easedProgress
//        } else {
//            if draggedOffset < 0 {
//                let progress = min(1, abs(draggedOffset) / 40)
//                let easedProgress = pow(progress, 0.7)
//                return easedProgress
//            } else {
//                return 0
//            }
//        }
//    }
//}
//
//private struct ProgressTracker: View, Animatable {
//    var progress: CGFloat = 0
//
//    nonisolated var animatableData: CGFloat {
//        get { progress }
//        set { progress = newValue }
//    }
//
//    var body: some View {
//        Color.clear
//            .frame(width: 1, height: 1)
//            .preference(key: NowPlayingExpandProgressPreferenceKey.self, value: progress)
//    }
//}
//
//private extension UIWindow {
//    func stacked(progress: CGFloat, animationDuration: TimeInterval?) {
//        if let animationDuration {
//            UIView.animate(
//                withDuration: animationDuration,
//                animations: {
//                    self.stacked(progress: progress)
//                },
//                completion: { _ in
//                    delay(animationDuration) {
//                        DispatchQueue.main.async {
//                            self.resetStacked()
//                        }
//                    }
//                }
//            )
//        } else {
//            stacked(progress: progress)
//        }
//    }
//
//    private func stacked(progress: CGFloat) {
//        let offsetY = progress * 10
//        layer.cornerRadius = 22
//        layer.masksToBounds = true
//
//        let scale = 1 - progress * 0.1
//        transform = .identity
//            .scaledBy(x: scale, y: scale)
//            .translatedBy(x: 0, y: offsetY)
//    }
//
//    func resetStackedWithAnimation(duration: TimeInterval) {
//        UIView.animate(withDuration: duration) {
//            DispatchQueue.main.async {
//                self.resetStacked()
//            }
//        }
//    }
//
//    private func resetStacked() {
//        layer.cornerRadius = 0.0
//        transform = .identity
//    }
//}
//
//func delay(_ seconds: TimeInterval, block: @escaping () -> Void) {
//    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
//}
//
//extension UIApplication {
//    static var keyWindow: UIWindow? {
//        UIApplication.shared.connectedScenes
//            .compactMap { $0 as? UIWindowScene }
//            .flatMap(\.windows)
//            .first { $0.isKeyWindow }
//    }
//}
//
//#Preview {
//    ExpandableNowPlaying(
//        show: .constant(true),
//        expanded: .constant(false)
//    )
//    .environment(MPD())
//}
