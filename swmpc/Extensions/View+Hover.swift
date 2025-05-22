//
//  View+Hover.swift
//  swmpc
//
//  Created by Camille Scholtz on 23/05/2025.
//

import SwiftUI

@MainActor
final class HoverTaskHandler {
    private var currentTask: Task<Void, Never>?

    func handleHover(_ isHovering: Bool, delay: Duration = .milliseconds(50), action: @escaping @MainActor () -> Void) {
        currentTask?.cancel()

        if isHovering {
            currentTask = Task {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }

                action()
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

extension View {
    func onHoverWithDebounce(
        delay: Duration = .milliseconds(50),
        handler: HoverTaskHandler,
        onHover: @escaping @MainActor (Bool) -> Void
    ) -> some View {
        self.onHover { isHovering in
            if isHovering {
                handler.handleHover(true, delay: delay) {
                    onHover(true)
                }
            } else {
                handler.cancel()
                onHover(false)
            }
        }
    }
}
