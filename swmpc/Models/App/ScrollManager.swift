//
//  ScrollManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/07/2025.
//

import SwiftUI

@Observable
final class ScrollManager {
    private var pendingScrollRequests: [ScrollRequest] = []
    private var isProcessingScroll = false
    private var lastScrollTime: Date?
    
    struct ScrollRequest {
        let id: String
        let destination: ScrollDestination
        let animate: Bool
        let timestamp: Date
    }
    
    enum ScrollDestination {
        case currentMedia
        case specificItem(id: AnyHashable)
    }
    
    func requestScroll(to destination: ScrollDestination, animate: Bool = true, context: String = "default") {
        let request = ScrollRequest(
            id: UUID().uuidString,
            destination: destination,
            animate: animate,
            timestamp: Date()
        )
        
        pendingScrollRequests.append(request)
        
        Task { @MainActor in
            await processScrollRequests()
        }
    }
    
    private func processScrollRequests() async {
        guard !isProcessingScroll else { return }
        guard !pendingScrollRequests.isEmpty else { return }
        
        isProcessingScroll = true
        defer { isProcessingScroll = false }
        
        // Debounce: wait a bit to collect multiple requests
        try? await Task.sleep(for: .milliseconds(100))
        
        // Take the most recent request
        guard let latestRequest = pendingScrollRequests.last else { return }
        pendingScrollRequests.removeAll()
        
        // Check if we've scrolled too recently
        if let lastTime = lastScrollTime, Date().timeIntervalSince(lastTime) < 0.5 {
            return
        }
        
        lastScrollTime = Date()
        
        // Post notification with the request
        NotificationCenter.default.post(
            name: .performScrollNotification,
            object: latestRequest
        )
    }
    
    func cancelPendingScrolls() {
        pendingScrollRequests.removeAll()
    }
}
