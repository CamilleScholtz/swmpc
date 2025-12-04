//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import Network
import SFSafeSymbols
import SwiftUI

#if os(macOS)
    import LaunchAtLogin
#endif

#if os(macOS)
    private extension Layout.Size {
        static let settingsWindowWidth: CGFloat = 500
    }
#endif

struct SettingsView: View {
    #if os(macOS)
        @State private var selection: SettingCategory? = .connections
    #endif

    private enum SettingCategory: String, Identifiable {
        case connections = "Connections"
        #if os(macOS)
            case behavior = "Behavior"
        #endif
        case intelligence = "Intelligence"

        var id: Self { self }
        var title: String { rawValue }

        #if os(iOS)
            static var allCases: [SettingCategory] {
                [.connections, .intelligence]
            }

        #elseif os(macOS)
            static var allCases: [SettingCategory] {
                [.connections, .behavior, .intelligence]
            }
        #endif

        var image: SFSymbol {
            switch self {
            case .connections: .point3ConnectedTrianglepathDotted
            #if os(macOS)
                case .behavior: .sliderHorizontal3
            #endif
            case .intelligence: .sparkles
            }
        }

        @ViewBuilder
        var view: some View {
            switch self {
            case .connections:
                ConnectionsView()
            #if os(macOS)
                case .behavior:
                    BehaviorView()
            #endif
            case .intelligence:
                IntelligenceView()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            NavigationStack {
                List {
                    ForEach(SettingCategory.allCases) { category in
                        NavigationLink(destination: category.view
                            .navigationTitle(category.title)
                            .navigationBarTitleDisplayMode(.inline))
                        {
                            Label(category.title, systemSymbol: category.image)
                        }
                    }

                    Section {
                        NavigationLink(destination: AboutView()
                            .navigationTitle("About")
                            .navigationBarTitleDisplayMode(.inline))
                        {
                            Label("About", systemSymbol: .infoCircle)
                        }
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
        #elseif os(macOS)
            TabView(selection: $selection) {
                ForEach(SettingCategory.allCases) { category in
                    category.view
                        .formStyle(.grouped)
                        .tabItem {
                            Label(category.title, systemSymbol: category.image)
                        }
                        .tag(category)
                        .navigationTitle(category.title)
                }
            }
            .frame(width: Layout.Size.settingsWindowWidth)
        #endif
    }

    struct ConnectionsView: View {
        @Environment(MPD.self) private var mpd
        @Environment(ServerManager.self) private var serverManager

        @State private var bonjour = BonjourManager()
        @State private var showingAddServer = false
        @State private var serverToEdit: Server?

        var body: some View {
            Form {
                #if os(iOS)
                    statusSection
                    serversSection
                    discoverySection
                #elseif os(macOS)
                    serversSection
                    discoverySection
                    statusSection
                #endif
            }
            .sheet(isPresented: $showingAddServer) {
                ServerEditView(server: nil)
            }
            .sheet(item: $serverToEdit) { server in
                ServerEditView(server: server)
            }
        }

        @ViewBuilder
        private var statusSection: some View {
            #if os(iOS)
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: Layout.Padding.small) {
                            Circle()
                                .fill(mpd.state.connectionColor)
                                .frame(width: 8, height: 8)
                            Text(mpd.state.connectionDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !mpd.state.isConnectionReady, let error = mpd.state.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .monospaced()
                            .foregroundColor(.secondary)
                    }
                }
            #elseif os(macOS)
                if !mpd.state.isConnectionReady, let error = mpd.state.error {
                    Section("Error") {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .monospaced()
                            .foregroundColor(.secondary)
                    }
                }
            #endif
        }

        @ViewBuilder
        private var serversSection: some View {
            #if os(iOS)
                Section {
                    ForEach(serverManager.servers) { server in
                        serverRow(for: server)
                    }
                    .onDelete { offsets in
                        serverManager.remove(atOffsets: offsets)
                    }

                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add Server", systemSymbol: .plus)
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    Text("Tap a server to connect. Tap the info button to edit settings.")
                }
            #elseif os(macOS)
                Section {
                    ForEach(serverManager.servers) { server in
                        serverRow(for: server)
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    HStack {
                        Spacer()

                        Button {
                            bonjour.scan()
                        } label: {
                            if bonjour.isScanning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Scan for Servers")
                            }
                        }
                        .disabled(bonjour.isScanning)

                        Button("Add Server") {
                            showingAddServer = true
                        }
                    }
                }
            #endif
        }

        @ViewBuilder
        private func serverRow(for server: Server) -> some View {
            let isSelected = serverManager.selectedServerID == server.id

            #if os(iOS)
                HStack {
                    Button {
                        Task {
                            serverManager.select(server)
                            await mpd.reinitialize()
                        }
                    } label: {
                        HStack {
                            if isSelected {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemSymbol: .checkmark)
                                    .hidden()
                            }

                            VStack(alignment: .leading) {
                                Text(server.displayName)
                                    .foregroundStyle(.primary)
                                Text("\(server.host):\(server.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        serverToEdit = server
                    } label: {
                        Image(systemSymbol: .infoCircle)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            #elseif os(macOS)
                ServerRow(server: server, isSelected: isSelected) {
                    Task {
                        serverManager.select(server)
                        await mpd.reinitialize()
                    }
                } onEdit: {
                    serverToEdit = server
                }
                .environment(mpd)
            #endif
        }

        @ViewBuilder
        private var discoverySection: some View {
            #if os(iOS)
                Section {
                    Button {
                        bonjour.scan()
                    } label: {
                        HStack {
                            Text("Scan for Servers")
                            Spacer()
                            if bonjour.isScanning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(bonjour.isScanning)
                } header: {
                    Text("Discovery")
                } footer: {
                    Text("Search for MPD servers on your local network using Bonjour.")
                }

                if !bonjour.servers.isEmpty {
                    Section {
                        ForEach(bonjour.servers) { discovered in
                            Button {
                                let server = Server(from: discovered)
                                serverManager.add(server)
                                serverManager.select(server)
                                serverToEdit = server
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading) {
                                        Text(discovered.displayName)
                                            .foregroundStyle(.primary)
                                        Text("\(discovered.host):\(discovered.port)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemSymbol: .plusCircle)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    } header: {
                        Text("Available Servers")
                    }
                }
            #elseif os(macOS)
                if !bonjour.servers.isEmpty {
                    Section("Discovered Servers") {
                        ForEach(bonjour.servers) { discovered in
                            Button {
                                let server = Server(from: discovered)
                                serverManager.add(server)
                                serverManager.select(server)
                                serverToEdit = server
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading) {
                                        Text(discovered.displayName)
                                        Text("\(discovered.host):\(discovered.port)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemSymbol: .plusCircle)
                                        .foregroundStyle(.tint)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            #endif
        }
    }

    #if os(macOS)
        struct BehaviorView: View {
            @AppStorage(Setting.showStatusBar) var showStatusBar = true
            @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true

            @State private var restartAlertShown = false
            @State private var isRestarting = false

            var body: some View {
                Form {
                    Section {
                        LaunchAtLogin.Toggle()
                            .help("Automatically start swmpc when you log in")
                    }

                    Section("Status Bar") {
                        Toggle("Show in Status Bar", isOn: $showStatusBar)
                            .help("Display swmpc icon in the menu bar")
                            .onChange(of: showStatusBar) {
                                NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                            }
                        Toggle(isOn: $showStatusbarSong) {
                            Text("Show Song in Status Bar")
                            Text("If this is disabled, only the icon will be shown.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .help("Display currently playing song next to the menu bar icon")
                        .disabled(!showStatusBar)
                        .onChange(of: showStatusbarSong) {
                            NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                        }
                    }
                }
            }
        }
    #endif

    struct IntelligenceView: View {
        @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false
        @AppStorage(Setting.intelligenceModel) var intelligenceModel = IntelligenceModel.openAI

        @State private var intelligenceToken = ""

        var body: some View {
            Form {
                #if os(iOS)
                    Section {
                        Toggle("Enable AI Features", isOn: $isIntelligenceEnabled)
                    } footer: {
                        Text("Powers smart playlist and queue generation using AI.")
                    }

                    Section {
                        Picker("Model", selection: $intelligenceModel) {
                            ForEach(IntelligenceModel.allCases.filter(\.isEnabled)) { model in
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                    Text(model.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .disabled(!isIntelligenceEnabled)

                        SecureField("API Token", text: $intelligenceToken)
                            .textContentType(.password)
                            .disabled(!isIntelligenceEnabled)
                    } header: {
                        Text("Provider")
                    } footer: {
                        Text("Enter your API token for the selected AI provider.")
                    }
                #elseif os(macOS)
                    Section {
                        Toggle(isOn: $isIntelligenceEnabled) {
                            Text("Enable AI Features")
                            Text("Powers smart playlist and queue generation using AI.")
                        }
                        .help("Enable AI-powered features for playlist generation")
                    }

                    Section("Provider") {
                        Picker("Model", selection: $intelligenceModel) {
                            ForEach(IntelligenceModel.allCases.filter(\.isEnabled)) { model in
                                HStack {
                                    Text(model.name)
                                    Text(model.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        .help("Select the AI model to use for intelligent features")
                        .disabled(!isIntelligenceEnabled)

                        SecureField("API Token", text: $intelligenceToken)
                            .textContentType(.password)
                            .help("API token for the selected AI service")
                            .disabled(!isIntelligenceEnabled)
                    }
                #endif
            }
            .onAppear {
                @AppStorage(intelligenceModel.setting) var token = ""
                intelligenceToken = token
            }
            .onChange(of: intelligenceToken) { _, value in
                @AppStorage(intelligenceModel.setting) var token = ""
                token = value.isEmpty ? "" : value
            }
            .onChange(of: intelligenceModel) {
                @AppStorage(intelligenceModel.setting) var token = ""
                intelligenceToken = token
            }
        }
    }
}

#if os(macOS)
    private struct ServerRow: View {
        @Environment(MPD.self) private var mpd

        let server: Server
        let isSelected: Bool
        let onConnect: () -> Void
        let onEdit: () -> Void

        @State private var isHovering = false

        var body: some View {
            HStack(spacing: Layout.Spacing.medium) {
                if isSelected {
                    Circle()
                        .fill(mpd.state.connectionColor)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading) {
                    Text(server.displayName)
                    Text("\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isHovering {
                    Button("Edit") {
                        onEdit()
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onConnect()
            }
            .onHover { hovering in
                isHovering = hovering
            }
        }
    }
#endif
