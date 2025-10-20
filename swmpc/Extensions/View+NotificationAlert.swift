//
//  View+NotificationAlert.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/10/2025.
//

import ButtonKit
import SwiftUI

extension View {
    /// Displays an alert when a notification is received.
    ///
    /// This modifier listens for a notification and automatically presents an
    /// alert when the notification is posted. It manages the presentation state
    /// internally.
    ///
    /// - Parameters:
    ///   - notification: The notification name to listen for
    ///   - title: The title of the alert
    ///   - actions: A ViewBuilder that produces the alert's action buttons
    ///   - message: A ViewBuilder that produces the alert's message content
    /// - Returns: A view that displays an alert when the notification is
    ///            received
    func notificationAlert(
        _ notification: Notification.Name,
        title: String,
        @ViewBuilder actions: @escaping () -> some View,
        @ViewBuilder message: @escaping () -> some View,
    ) -> some View {
        modifier(NotificationAlertModifier(
            notification: notification,
            title: title,
            actions: actions,
            message: message,
        ))
    }
}

/// View modifier that displays an alert when a specific notification is
/// received.
private struct NotificationAlertModifier<A: View, M: View>: ViewModifier {
    let notification: Notification.Name
    let title: String
    let actions: () -> A
    let message: () -> M

    @State private var isPresented = false

    private var notificationPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: notification)
    }

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                actions()
            } message: {
                message()
            }
            .onReceive(notificationPublisher) { _ in
                isPresented = true
            }
    }
}
