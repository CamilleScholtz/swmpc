//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

actor ArtworkManager {
    static let shared = ArtworkManager()

    private let cache = NSCache<NSURL, NSData>()

    private init() {
        cache.countLimit = 64
    }

    func get(using url: URL, shouldCache: Bool = true) async throws -> Data {
        if shouldCache, let data = cache.object(forKey: url as NSURL) {
            return data as Data
        }

        let data = try await ConnectionManager.command().getArtworkData(for: url)

        if shouldCache {
            cache.setObject(data as NSData, forKey: url as NSURL)
        }

        return data
    }
}
