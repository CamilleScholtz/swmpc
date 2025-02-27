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
    // Define the sections in the sidebar.
    enum SettingSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case premium = "Premium Features"

        var id: Self { self }
        var title: String { rawValue }

        // Provide system images that fit the context.
        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .appearance: "paintpalette"
            case .premium: "star.circle"
            }
        }
    }

    @State private var selection: SettingSection? = .general

    var body: some View {
        NavigationView {
            // Sidebar list with NavigationLinks
            List(selection: $selection) {
                ForEach(SettingSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            // Default detail view when nothing is selected.
            Text("Select a setting from the sidebar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Navigation split (new in macOS 13) is another option, but NavigationView works well too.
        .navigationTitle("Settings")
        .frame(width: 700, height: 500)
        // For macOS Monterey and earlier, use a NavigationLink-based sidebar:
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: toggleSidebar, label: {
                    Image(systemName: "sidebar.leading")
                })
            }
        }
        .navigationDestination(for: SettingSection.self) { section in
            switch section {
            case .general:
                GeneralView()
            case .appearance:
                AppearanceView()
            case .premium:
                PremiumView()
            }
        }
    }

    // Helper to toggle the sidebar (works on macOS)
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct GeneralView: View {
    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    var body: some View {
        Form {
            Section(header: Text("Startup")) {
                LaunchAtLogin.Toggle()
                    .padding(.vertical, 4)
            }
            Section(header: Text("Connection")) {
                TextField("Host", text: $host)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Port", value: $port, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .navigationTitle("General")
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
        .navigationTitle("Appearance")
    }
}

struct PremiumView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.title)
                .bold()
            Text("Upgrade to premium to unlock additional features such as advanced customization options, priority support, and more.")
                .foregroundColor(.secondary)
            Button("Upgrade Now") {
                // Insert your upgrade action (e.g. open a URL)
                if let url = URL(string: "https://www.example.com/upgrade") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Premium Features")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
