//
//  View+Hover.swift
//  swmpc
//
//  Created by Camille Scholtz on 23/05/2025.
//

import SwiftUI

/// Manages hover events with debouncing to prevent rapid triggering.
/// Cancels any pending hover action when hover state changes.
final class HoverTaskHandler {
    private var currentTask: Task<Void, Never>?

    /// Handles hover state changes with an optional delay before executing the
    /// action.
    ///
    /// - Parameters:
    ///   - isHovering: Whether the view is currently being hovered over.
    ///   - delay: The delay before executing the action (default: 50ms).
    ///   - action: The closure to execute after the delay.
    func handleHover(_ isHovering: Bool, delay: Duration = .milliseconds(50), action: @escaping () -> Void) {
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

    /// Cancels any pending hover action.
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

extension View {
    /// Adds hover handling with debouncing to prevent rapid triggering.
    ///
    /// - Parameters:
    ///   - delay: The delay before the hover action is triggered (default:
    ///            50ms).
    ///   - handler: The HoverTaskHandler instance managing the debounced hover
    ///              state.
    ///   - onHover: Closure called with the hover state after debouncing.
    /// - Returns: A view with debounced hover handling.
    func onHoverWithDebounce(
        delay: Duration = .milliseconds(50),
        handler: HoverTaskHandler,
        onHover: @escaping (Bool) -> Void,
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
