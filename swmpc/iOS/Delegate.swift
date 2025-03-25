//
//  Delegate.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/03/2025.
//

import SFSafeSymbols
import SwiftUI

@main
struct Delegate: App {
    let mpd = MPD()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(mpd)
        }

//        Settings {
//            SettingsView()
//        }
    }
}
