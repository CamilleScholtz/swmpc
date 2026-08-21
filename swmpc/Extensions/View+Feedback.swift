//
//  View+Feedback.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import SwiftUI

/// A one-shot sensory feedback trigger for user-initiated actions.
///
/// Playback state also changes from outside the app — another MPD client, a
/// media key, an App Intent — and feedback for those changes would fire
/// unprompted in the user's pocket. Views therefore drive this from their
/// button actions rather than observing `mpd`.
struct ActionFeedback: Equatable {
    private var count = 0
    private(set) var feedback: SensoryFeedback?

    /// Plays `feedback` once.
    ///
    /// - Parameter feedback: The feedback to play.
    mutating func play(_ feedback: SensoryFeedback) {
        self.feedback = feedback
        count += 1
    }
}

extension View {
    /// Plays sensory feedback every time `trigger` fires via
    /// ``ActionFeedback/play(_:)``.
    ///
    /// - Parameter trigger: The view's feedback state.
    /// - Returns: A view that plays feedback for user-initiated actions.
    func actionFeedback(_ trigger: ActionFeedback) -> some View {
        sensoryFeedback(trigger: trigger) { _, value in
            value.feedback
        }
    }
}
