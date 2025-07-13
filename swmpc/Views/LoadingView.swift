
import SwiftUI

struct LoadingView: View {
    @Environment(LoadingManager.self) private var loadingManager

    var body: some View {
        if loadingManager.isLoading {
            ZStack {
                  Rectangle()
                      .fill(.background)
                      .ignoresSafeArea()

                  ProgressView()
                      .controlSize(.large)
              }
              .transition(.asymmetric(
                  insertion: .opacity,
                  removal: .opacity.animation(.easeOut(duration: 0.2).delay(0.2))
              ))
        }
    }
}
