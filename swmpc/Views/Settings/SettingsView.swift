//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import LaunchAtLogin
import SwiftUI

enum Setting {
    static let host = "host"
    static let port = "port"

    static let showStatusBar = "showStatusBar"
    static let showStatusbarSong = "showStatusbarSong"
}

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralView()
            }

            Tab("Appearance", systemImage: "paintpalette") {
                AppearanceView()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    struct GeneralView: View {
        @AppStorage(Setting.host) var host = "localhost"
        @AppStorage(Setting.port) var port = 6600

        var body: some View {
            Form {
                Section(header: Text("Startup")) {
                    LaunchAtLogin.Toggle()
                }

                Section(header: Text("Connection")) {
                    TextField("Host", text: $host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Port", value: $port, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding()
        }
    }

    struct AppearanceView: View {
        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true

        var body: some View {
            Form {
                Section(header: Text("Status Bar")) {
                    Toggle("Show Status Bar", isOn: $showStatusBar)
                    Toggle("Show Song in Status Bar", isOn: $showStatusbarSong)
                }
            }
            .padding()
        }
    }
}
