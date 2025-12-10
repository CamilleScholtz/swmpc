//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import MPDKit
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
                serversSection
                statusSection
                discoverySection
            }
            .sheet(isPresented: $showingAddServer) {
                ServerEditView(server: nil)
            }
            .sheet(item: $serverToEdit) { server in
                ServerEditView(server: server)
            }
        }

        @ViewBuilder
        private var serversSection: some View {
            Section {
                if serverManager.servers.isEmpty {
                    Button("Add Server") {
                        showingAddServer = true
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(serverManager.servers) { server in
                        ServerRow(
                            server: server,
                            isSelected: serverManager.selectedServerID == server.id,
                        ) {
                            Task(priority: .userInitiated) {
                                serverManager.select(server)
                                await mpd.reinitialize()
                            }
                        } onEdit: {
                            serverToEdit = server
                        }
                    }
                    #if os(iOS)
                    .onDelete { offsets in
                        serverManager.remove(atOffsets: offsets)
                    }
                    #endif

                    #if os(iOS)
                        Button("Add Server") {
                            showingAddServer = true
                        }
                    #endif
                }
            } header: {
                Text("My Servers")
            } footer: {
                #if os(macOS)
                    if !serverManager.servers.isEmpty {
                        HStack {
                            Spacer()

                            Button("Add Server") {
                                showingAddServer = true
                            }
                        }
                    }
                #endif
            }
        }

        @ViewBuilder
        private var statusSection: some View {
            if !mpd.state.isConnectionReady, let error = mpd.state.error {
                Section("Error") {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .monospaced()
                        .foregroundColor(.secondary)
                }
            }
        }

        @ViewBuilder
        private var discoverySection: some View {
            Section {
                if bonjour.servers.isEmpty {
                    Text("Searching...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(bonjour.servers) { discovered in
                        Button {
                            let server = Server(from: discovered)

                            serverManager.add(server)
                            serverManager.select(server)

                            serverToEdit = server
                        } label: {
                            HStack(spacing: Layout.Spacing.large) {
                                Circle()
                                    .fill(.gray.opacity(0.5))
                                    .frame(width: 9, height: 9)

                                VStack(alignment: .leading) {
                                    Text(discovered.displayName)
                                    Text(verbatim: "\(discovered.host):\(discovered.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("Discovered Servers")

                    Spacer()

                    if bonjour.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .task {
                while !Task.isCancelled {
                    bonjour.scan()
                    try? await Task.sleep(for: .seconds(10))
                }
            }
        }

        private struct ServerRow: View {
            @Environment(MPD.self) private var mpd

            let server: Server
            let isSelected: Bool
            let onConnect: () -> Void
            let onEdit: () -> Void

            #if os(macOS)
                @State private var isHovering = false
            #endif

            var body: some View {
                HStack(spacing: Layout.Spacing.large) {
                    Circle()
                        .fill(isSelected ? mpd.state.connectionColor : .gray.opacity(0.5))
                        .frame(width: 9, height: 9)

                    VStack(alignment: .leading) {
                        Text(server.displayName)
                        Text(verbatim: "\(server.host):\(server.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    #if os(iOS)
                        Button {
                            onEdit()
                        } label: {
                            Image(systemSymbol: .infoCircle)
                                .font(Font.system(size: 18))
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    #elseif os(macOS)
                        if isHovering {
                            Button("Edit") {
                                onEdit()
                            }
                        }
                    #endif
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onConnect()
                }
                #if os(macOS)
                .onHover { hovering in
                    isHovering = hovering
                }
                #endif
            }
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
