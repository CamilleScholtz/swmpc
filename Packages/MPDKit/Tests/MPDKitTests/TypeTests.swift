//
//  TypeTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
@testable import MPDKit
import Testing

@Suite("Audio format")
struct AudioFormatTests {
    @Test
    func `A complete triplet is read field by field`() throws {
        let format = try #require(AudioFormat("44100:16:2"))

        #expect(format.sampleRate == 44100)
        #expect(format.bits == 16)
        #expect(format.channels == 2)
    }

    @Test
    func `A DSD source has a sample rate and channels but no bit depth`() throws {
        let format = try #require(AudioFormat("2822400:dsd:2"))

        #expect(format.sampleRate == 2_822_400)
        #expect(format.bits == nil)
        #expect(format.channels == 2)
    }

    @Test
    func `Placeholders and zeroes read as unknown, not as zero`() throws {
        let format = try #require(AudioFormat("44100:*:0"))

        #expect(format.sampleRate == 44100)
        #expect(format.bits == nil)
        #expect(format.channels == nil)
    }

    @Test
    func `A format that says nothing at all is no format`() {
        #expect(AudioFormat("*:*:*") == nil)
        #expect(AudioFormat("0:0:0") == nil)
    }

    @Test
    func `Anything that is not a triplet is rejected`() {
        #expect(AudioFormat("") == nil)
        #expect(AudioFormat("44100") == nil)
        #expect(AudioFormat("44100:16") == nil)
        #expect(AudioFormat("44100:16:2:1") == nil)
    }

    @Test
    func `An empty field is unknown rather than malformed`() throws {
        let format = try #require(AudioFormat("44100::2"))

        #expect(format.bits == nil)
        #expect(format.channels == 2)
    }

    @Test
    func `Two identical formats compare and hash alike`() {
        #expect(AudioFormat("44100:16:2") == AudioFormat("44100:16:2"))
        #expect(AudioFormat("44100:16:2") != AudioFormat("48000:16:2"))
        #expect(AudioFormat("44100:*:2") == AudioFormat("44100:0:2"))
    }
}

@Suite("Sort descriptors")
struct SortDescriptorTests {
    @Test
    func `The default sorts artists ascending`() {
        #expect(SortDescriptor.default.option == .artist)
        #expect(SortDescriptor.default.direction == .ascending)
        #expect(SortDescriptor(option: .album).direction == .ascending)
    }

    @Test
    func `A descriptor survives its string representation`() {
        let options: [SortOption] = [.artist, .album, .song, .modified]
        let directions: [SortDirection] = [.ascending, .descending]

        for option in options {
            for direction in directions {
                let descriptor = SortDescriptor(option: option,
                                                direction: direction)

                #expect(SortDescriptor(rawValue: descriptor.rawValue)
                    == descriptor)
            }
        }
    }

    @Test
    func `The representation names the tag and spells out the direction`() {
        #expect(SortDescriptor(option: .album).rawValue
            == "albumsort_ascending")
        #expect(SortDescriptor(option: .song, direction: .descending).rawValue
            == "titlesort_descending")
    }

    @Test
    func `A representation without a direction is ascending`() {
        #expect(SortDescriptor(rawValue: "albumsort")
            == SortDescriptor(option: .album, direction: .ascending))
    }

    @Test
    func `Anything unreadable falls back to the default`() {
        #expect(SortDescriptor(rawValue: "") == .default)
        #expect(SortDescriptor(rawValue: "nonesuch") == .default)
        #expect(SortDescriptor(rawValue: "_descending") == .default)
    }

    @Test
    func `Only a direction spelled out in full sorts descending`() {
        #expect(SortDescriptor(rawValue: "albumsort_desc").direction
            == .ascending)
        #expect(SortDescriptor(rawValue: "albumsort_descending_extra")
            .direction == .ascending)
    }

    @Test
    func `Descriptors are hashable by what they sort on`() {
        #expect(Set([SortDescriptor(option: .album),
                     SortDescriptor(option: .album),
                     SortDescriptor(option: .album,
                                    direction: .descending)]).count == 2)
    }

    @Test
    func `The direction is the prefix MPD wants on the tag`() {
        #expect(SortDirection.ascending.rawValue.isEmpty)
        #expect(SortDirection.descending.rawValue == "-")
    }

    @Test
    func `Only sorting by song title needs a recent server`() {
        #expect(SortOption.song.minimumVersion == "0.24")
        #expect(SortOption.artist.minimumVersion == nil)
        #expect(SortOption.album.minimumVersion == nil)
        #expect(SortOption.modified.minimumVersion == nil)
    }
}

@Suite("Search fields")
struct SearchFieldsTests {
    @Test
    func `Nothing is searched by default`() {
        #expect(SearchFields.default.isEmpty)
        #expect(SearchFields().isEmpty)
        #expect(SearchFields.default.rawValue.isEmpty)
    }

    @Test
    func `Toggling adds a field, and toggling again takes it away`() {
        var fields = SearchFields()

        fields.toggle(.title)
        #expect(fields.contains(.title))
        #expect(!fields.isEmpty)

        fields.toggle(.artist)
        #expect(fields.contains(.artist))

        fields.toggle(.title)
        #expect(!fields.contains(.title))
        #expect(fields.contains(.artist))
    }

    @Test
    func `The selection survives its string representation`() {
        let fields = SearchFields(fields: [.title, .artist, .mood])

        #expect(SearchFields(rawValue: fields.rawValue) == fields)
    }

    @Test
    func `The representation is stable, whatever order fields were added in`() {
        #expect(SearchFields(fields: [.mood, .artist, .title]).rawValue
            == "Artist,Mood,Title")
        #expect(SearchFields(fields: [.title, .mood, .artist]).rawValue
            == SearchFields(fields: [.mood, .artist, .title]).rawValue)
    }

    @Test
    func `An empty representation selects nothing`() {
        #expect(SearchFields(rawValue: "").isEmpty)
    }

    @Test
    func `Fields that are no longer known are dropped when read back`() {
        let fields = SearchFields(rawValue: "Title,Nonesuch,Artist")

        #expect(fields.contains(.title))
        #expect(fields.contains(.artist))
        #expect(fields.fields == ["title", "artist"])
    }

    @Test
    func `Queries want the field names lower-cased, as tags are`() {
        #expect(SearchFields(fields: [.album, .title]).fields
            == ["album", "title"])
        #expect(SearchFields().fields.isEmpty)
    }

    @Test
    func `Two selections of the same fields are equal`() {
        #expect(SearchFields(fields: [.title, .artist])
            == SearchFields(fields: [.artist, .title]))
        #expect(SearchFields(fields: [.title]) != SearchFields(fields: [.mood]))
    }

    @Test
    func `Only the tags MPD gained recently need a recent server`() {
        #expect(SearchField.conductor.minimumVersion == "0.22")
        #expect(SearchField.ensemble.minimumVersion == "0.23")
        #expect(SearchField.mood.minimumVersion == "0.24")

        for field in [SearchField.title, .artist, .album, .genre, .composer,
                      .performer, .comment]
        {
            #expect(field.minimumVersion == nil)
        }
    }

    @Test
    func `Every search field names a tag MPDKit reads`() {
        let tags = Set(TagType.allCases.map(\.identifier))

        for field in SearchField.allCases {
            #expect(tags.contains(field.rawValue.lowercased()))
        }
    }
}

@Suite("Sources")
struct SourceTests {
    @Test
    func `Only a playlist source names a playlist`() {
        let playlist = Playlist(name: "Focus")

        #expect(Source.database.playlist == nil)
        #expect(Source.queue.playlist == nil)
        #expect(Source.playlist(playlist).playlist == playlist)
        #expect(Source.favorites.playlist == Playlist(name: "Favorites"))
    }

    @Test
    func `Everything but the database holds its own order`() {
        #expect(!Source.database.isReorderable)
        #expect(Source.queue.isReorderable)
        #expect(Source.playlist(Playlist(name: "Focus")).isReorderable)
        #expect(Source.favorites.isReorderable)
    }

    @Test
    func `Only the database can be asked to sort`() {
        #expect(Source.database.isSortable)
        #expect(!Source.queue.isSortable)
        #expect(!Source.playlist(Playlist(name: "Focus")).isSortable)
        #expect(!Source.favorites.isSortable)
    }

    @Test
    func `Nothing is both reorderable and sortable`() {
        for source in [Source.database, .queue, .favorites,
                       .playlist(Playlist(name: "Focus"))]
        {
            #expect(source.isReorderable != source.isSortable)
        }
    }

    @Test
    func `Each media type is searched on the fields it carries`() {
        #expect(Source.database.availableSearchFields(for: .album)
            == [.title, .artist])
        #expect(Source.database.availableSearchFields(for: .artist)
            == [.artist])
        #expect(Source.database.availableSearchFields(for: .song)
            == [.title, .artist, .genre, .composer, .performer, .conductor,
                .ensemble, .mood, .comment])
        #expect(Source.database.availableSearchFields(for: .playlist).isEmpty)
    }

    @Test
    func `The default search fields are always ones on offer`() {
        for type in [MediaType.album, .artist, .song, .playlist] {
            let available = Set(Source.database.availableSearchFields(for: type))
            let defaults = Source.database.defaultSearchFields(for: type)

            for field in SearchField.allCases where defaults.contains(field) {
                #expect(available.contains(field))
            }
        }
    }

    @Test
    func `Songs default to searching titles and artists`() {
        let defaults = Source.database.defaultSearchFields(for: .song)

        #expect(defaults.fields == ["title", "artist"])
        #expect(Source.database.defaultSearchFields(for: .playlist).isEmpty)
    }

    @Test
    func `Each media type sorts on the tags it has`() {
        #expect(Source.database.availableSortOptions(for: .album)
            == [.artist, .album, .modified])
        #expect(Source.database.availableSortOptions(for: .artist)
            == [.artist, .modified])
        #expect(Source.database.availableSortOptions(for: .song)
            == [.album, .song, .artist, .modified])
        #expect(Source.database.availableSortOptions(for: .playlist).isEmpty)
    }

    @Test
    func `What a source offers does not depend on which source it is`() {
        let queue = Source.queue

        #expect(queue.availableSortOptions(for: .song)
            == Source.database.availableSortOptions(for: .song))
        #expect(queue.availableSearchFields(for: .song)
            == Source.database.availableSearchFields(for: .song))
    }

    @Test
    func `Sources are hashable by what they point at`() {
        let focus = Source.playlist(Playlist(name: "Focus"))
        let sleep = Source.playlist(Playlist(name: "Sleep"))

        #expect(focus == Source.playlist(Playlist(name: "Focus")))
        #expect(focus != sleep)
        #expect(focus != .favorites)
        #expect(Set([focus, sleep, focus]).count == 2)
    }
}

@Suite("Idle events")
struct IdleEventTests {
    @Test
    func `Subsystems are spelled as the protocol spells them`() {
        #expect(IdleEvent.database.rawValue == "database")
        #expect(IdleEvent.playlists.rawValue == "stored_playlist")
        #expect(IdleEvent.queue.rawValue == "playlist")
        #expect(IdleEvent.options.rawValue == "options")
        #expect(IdleEvent.player.rawValue == "player")
        #expect(IdleEvent.mixer.rawValue == "mixer")
        #expect(IdleEvent.output.rawValue == "output")
    }

    @Test
    func `The queue and stored playlists are not confused for each other`() {
        #expect(IdleEvent(rawValue: "playlist") == .queue)
        #expect(IdleEvent(rawValue: "stored_playlist") == .playlists)
    }

    @Test
    func `A subsystem MPDKit does not watch is ignored`() {
        #expect(IdleEvent(rawValue: "sticker") == nil)
        #expect(IdleEvent(rawValue: "") == nil)
    }
}

@Suite("Tag types")
struct TagTypeTests {
    @Test
    func `A tag is spelled for tagtypes and matched lower-cased`() {
        #expect(TagType.albumArtistSort.rawValue == "AlbumArtistSort")
        #expect(TagType.albumArtistSort.identifier == "albumartistsort")

        for tag in TagType.allCases {
            #expect(tag.identifier == tag.rawValue.lowercased())
        }
    }

    @Test
    func `No two tags share a name`() {
        #expect(Set(TagType.allCases.map(\.rawValue)).count
            == TagType.allCases.count)
        #expect(Set(TagType.allCases.map(\.identifier)).count
            == TagType.allCases.count)
    }

    @Test
    func `Tags are recovered from the spelling the server sends back`() {
        for tag in TagType.allCases {
            #expect(TagType(rawValue: tag.rawValue) == tag)
        }
    }
}

@Suite("Artwork retrieval")
struct ArtworkGetterTests {
    @Test
    func `Each setting names the commands to try, in order`() {
        #expect(ArtworkGetter.library.commands == ["albumart"])
        #expect(ArtworkGetter.metadata.commands == ["readpicture"])
        #expect(ArtworkGetter.libraryThenMetadata.commands
            == ["albumart", "readpicture"])
        #expect(ArtworkGetter.metadataThenLibrary.commands
            == ["readpicture", "albumart"])
    }

    @Test
    func `A stored setting survives a round trip`() throws {
        for getter in [ArtworkGetter.library, .metadata, .libraryThenMetadata,
                       .metadataThenLibrary]
        {
            let decoded = try JSONDecoder()
                .decode(ArtworkGetter.self,
                        from: JSONEncoder().encode(getter))

            #expect(decoded == getter)
        }
    }

    @Test
    func `A setting is stored under a name that must not change`() {
        #expect(ArtworkGetter.library.rawValue == "albumart")
        #expect(ArtworkGetter.metadata.rawValue == "readpicture")
        #expect(ArtworkGetter.libraryThenMetadata.rawValue
            == "albumart_then_readpicture")
        #expect(ArtworkGetter.metadataThenLibrary.rawValue
            == "readpicture_then_albumart")
    }
}

@Suite("Connection modes")
struct ConnectionModeTests {
    @Test
    func `Artwork reads in larger blocks than commands do`() {
        #expect(CommandMode.bufferSize == 4096)
        #expect(IdleMode.bufferSize == 4096)
        #expect(ArtworkMode.bufferSize == 8192)
        #expect(ArtworkMode.bufferSize > CommandMode.bufferSize)
    }
}

@Suite("Connection state")
struct ConnectionStateTests {
    @Test
    func `A failed or refused connection is dropped rather than waited on`() {
        #expect(ConnectionState.failed(reason: "boom").requiresDisconnect)
        #expect(ConnectionState.waiting(reason: "refused", isRefused: true)
            .requiresDisconnect)
    }

    @Test
    func `A connection that may still come up is kept`() {
        #expect(!ConnectionState.setup.requiresDisconnect)
        #expect(!ConnectionState.preparing.requiresDisconnect)
        #expect(!ConnectionState.ready.requiresDisconnect)
        #expect(!ConnectionState.cancelled.requiresDisconnect)
        #expect(!ConnectionState.waiting(reason: "no route", isRefused: false)
            .requiresDisconnect)
    }

    @Test
    func `States compare by their reasons as well as their cases`() {
        #expect(ConnectionState.ready == .ready)
        #expect(ConnectionState.failed(reason: "a") != .failed(reason: "b"))
        #expect(ConnectionState.waiting(reason: "a", isRefused: true)
            != .waiting(reason: "a", isRefused: false))
    }
}

@Suite("Connection errors")
struct ConnectionErrorTests {
    /// One of each error, so a new case has to be added here too.
    private let errors: [ConnectionManagerError] = [
        .invalidHost, .invalidPort, .unsupportedServerVersion,
        .connectionFailure("details"), .connectionUnexpectedClosure,
        .commandAlreadyInFlight, .protocolViolation("ACK [5@0]"),
        .malformedResponse("details"), .unsupportedOperation("details"),
    ]

    @Test
    func `Every error can say what went wrong`() {
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test
    func `The server's own words are carried into the description`() {
        #expect(ConnectionManagerError.protocolViolation("ACK [5@0]")
            .errorDescription?.contains("ACK [5@0]") == true)
        #expect(ConnectionManagerError.connectionFailure("no route")
            .errorDescription?.contains("no route") == true)
    }

    @Test
    func `The supported floor is named, so it can be acted on`() {
        #expect(ConnectionManagerError.unsupportedServerVersion
            .errorDescription?.contains("0.21") == true)
        #expect(ConnectionManagerError.invalidPort
            .errorDescription?.contains("65535") == true)
    }

    @Test
    func `Errors compare by case and by detail`() {
        #expect(ConnectionManagerError.invalidHost != .invalidPort)
        #expect(ConnectionManagerError.malformedResponse("a")
            == .malformedResponse("a"))
        #expect(ConnectionManagerError.malformedResponse("a")
            != .malformedResponse("b"))
        #expect(ConnectionManagerError.malformedResponse("a")
            != .protocolViolation("a"))
    }
}
