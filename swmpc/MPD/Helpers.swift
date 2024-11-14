//
//  Helpers.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import libmpdclient

func mpd_search_add_or_tag_constraint(
    _ connection: OpaquePointer?,
    _ tag1: mpd_tag_type,
    _ tag2: mpd_tag_type,
    _ query: String
) -> [String] {
    var results: Set<String> = []
    
    func performTagSearch(tag: mpd_tag_type) {
        guard mpd_search_db_songs(connection, false),
              mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, tag, query),
              mpd_search_commit(connection) else {
            return
        }
        
        while let song = mpd_recv_song(connection) {
            if let title = mpd_song_get_tag(song, MPD_TAG_TITLE, 0) {
                results.insert(String(cString: title))
            }
            mpd_song_free(song)
        }
        
        mpd_search_cancel(connection)
    }
    
    performTagSearch(tag: tag1)
    performTagSearch(tag: tag2)
    
    return Array(results)
}
