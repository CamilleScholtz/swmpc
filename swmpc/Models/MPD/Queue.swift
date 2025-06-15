import Foundation
import SwiftUI

@Observable
final class Queue: Sendable {
    @MainActor private(set) var songs: [Song] = []
    @MainActor private(set) var currentSong: Song?
    @MainActor private(set) var isLoading = false
    @MainActor private(set) var error: QueueError?
    
    enum QueueError: LocalizedError {
        case loadFailed
        case addFailed
        case clearFailed
        
        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return "Failed to load queue"
            case .addFailed:
                return "Failed to add to queue"
            case .clearFailed:
                return "Failed to clear queue"
            }
        }
    }
    
    init() {
    }
    
    @MainActor
    func load() async {
        isLoading = true
        error = nil
        
        do {
            let songs = try await ConnectionManager.command().getSongs(using: .queue)
            self.songs = songs
        } catch {
            self.error = .loadFailed
            self.songs = []
        }
        
        isLoading = false
    }
    
    @MainActor
    func reload() async {
        await load()
    }
    
    @MainActor
    func clear() async throws {
        do {
            try await ConnectionManager.command().clearQueue()
            songs = []
            error = nil
        } catch {
            self.error = .clearFailed
            throw error
        }
    }
    
    @MainActor
    func add(songs: [Song]) async throws {
        do {
            try await ConnectionManager.command().addToQueue(songs: songs)
            await load()
        } catch {
            self.error = .addFailed
            throw error
        }
    }
    
    @MainActor
    func add(album: Album) async throws {
        do {
            try await ConnectionManager.command().addToQueue(album: album)
            await load()
        } catch {
            self.error = .addFailed
            throw error
        }
    }
    
    @MainActor
    func add(artist: Artist) async throws {
        do {
            try await ConnectionManager.command().addToQueue(artist: artist)
            await load()
        } catch {
            self.error = .addFailed
            throw error
        }
    }
    
    @MainActor
    func loadPlaylist(_ playlist: Playlist) async throws {
        do {
            try await ConnectionManager.command().loadPlaylist(playlist)
            await load()
        } catch {
            self.error = .loadFailed
            throw error
        }
    }
    
    @MainActor
    func updateCurrentSong(_ song: Song?) {
        currentSong = song
    }
    
    @MainActor
    func reset() {
        songs = []
        currentSong = nil
        error = nil
        isLoading = false
    }
}