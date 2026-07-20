//
//  SettingsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import MPDKit
import MusicKit
import SFSafeSymbols
import SwiftUI

#if os(macOS)
    import ServiceManagement
#endif

#if os(macOS)
    private extension Layout.Size {
        static let settingsWindowWidth: CGFloat = 500
    }
#endif

struct SettingsView: View {
    #if os(macOS)
        @State private var selection: SettingCategory = .connections
    #endif

    private enum SettingCategory: Identifiable {
        case connections
        #if os(macOS)
            case behavior
        #endif
        case intelligence

        var id: Self {
            self
        }

        var title: LocalizedStringResource {
            switch self {
            case .connections: "Connections"
            #if os(macOS)
                case .behavior: "Behavior"
            #endif
            case .intelligence: "Intelligence"
            }
        }

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
                IntelligenceSettingsView()
            }
        }
    }

    var body: some View {
        #if os(iOS)
            NavigationStack {
                List {
                    ForEach(SettingCategory.allCases) { category in
                        NavigationLink(destination: category.view
                            .navigationTitle(Text(category.title))
                            .navigationBarTitleDisplayMode(.inline))
                        {
                            Label {
                                Text(category.title)
                            } icon: {
                                Image(systemSymbol: category.image)
                            }
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
                    Tab(value: category) {
                        category.view
                            .formStyle(.grouped)
                            .navigationTitle(Text(category.title))
                    } label: {
                        Label {
                            Text(category.title)
                        } icon: {
                            Image(systemSymbol: category.image)
                        }
                    }
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
                        .foregroundStyle(.secondary)
                }
            }
        }

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
                Button {
                    onConnect()
                } label: {
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
                                    .font(.title3)
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
                }
                .buttonStyle(.plain)
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
                        LaunchAtLoginToggle()
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
                                .foregroundStyle(.secondary)
                        }
                        .help("Display currently playing song next to the menu bar icon")
                        .disabled(!showStatusBar)
                        .onChange(of: showStatusbarSong) {
                            NotificationCenter.default.post(name: .statusBarSettingChangedNotification, object: nil)
                        }
                    }

                    AppleMusicSection()
                }
            }
        }

        private struct AppleMusicSection: View {
            @State private var status = MusicAuthorization.currentStatus

            var body: some View {
                Section {
                    LabeledContent("Apple Music Access") {
                        HStack(spacing: Layout.Spacing.small) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 9, height: 9)

                            statusText
                        }
                    }

                    if status == .notDetermined {
                        Button("Allow Access") {
                            Task(priority: .userInitiated) {
                                status = await MusicAuthorization.request()
                            }
                        }
                        .help("Ask macOS for permission to access Apple Music")
                    } else if status == .denied {
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .help("Access was denied; it can be re-enabled in System Settings under Privacy & Security")
                    }
                } header: {
                    Text("Apple Music")
                } footer: {
                    Text("Artist images are fetched from the Apple Music catalog, which requires permission to access Apple Music.")
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    status = MusicAuthorization.currentStatus
                }
            }

            private var statusColor: Color {
                switch status {
                case .authorized: .green
                case .denied, .restricted: .red
                default: .gray.opacity(0.5)
                }
            }

            private var statusText: Text {
                switch status {
                case .authorized: Text("Allowed")
                case .denied: Text("Denied")
                case .restricted: Text("Restricted")
                case .notDetermined: Text("Not Requested")
                @unknown default: Text("Unknown")
                }
            }
        }

        struct LaunchAtLoginToggle: View {
            @State private var isEnabled = SMAppService.mainApp.status == .enabled

            var body: some View {
                Toggle("Launch at Login", isOn: $isEnabled)
                    .onChange(of: isEnabled) {
                        do {
                            if isEnabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            isEnabled = SMAppService.mainApp.status == .enabled
                        }
                    }
                    .onAppear {
                        isEnabled = SMAppService.mainApp.status == .enabled
                    }
            }
        }
    #endif

    struct IntelligenceSettingsView: View {
        @AppStorage(Setting.intelligenceModel) private var provider = IntelligenceProvider.apple
        @AppStorage(Setting.customHost) private var customHost = ""

        @State private var token = ""
        @State private var modelID = ""

        var body: some View {
            Form {
                Section {
                    Picker("Provider", selection: $provider) {
                        ForEach(IntelligenceProvider.allCases) { item in
                            Text(item.name).tag(item)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #elseif os(macOS)
                    .help("Select the AI provider")
                    #endif

                    if provider == .apple, !PrivateCloudCompute.isAvailable {
                        Text("Apple Intelligence is not available on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if provider == .custom {
                        TextField("Base URL", text: $customHost)
                            .autocorrectionDisabled()
                        #if os(iOS)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                        #elseif os(macOS)
                            .help("Base URL of your OpenAI-compatible API (e.g. http://localhost:11434/v1)")
                        #endif
                    }

                    if provider != .apple {
                        TextField("Model", text: $modelID)
                            .autocorrectionDisabled()
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #elseif os(macOS)
                            .help(provider == .custom ? "Model identifier (e.g. llama3, mistral)" : "Model identifier for the selected provider")
                        #endif

                        SecureField("API Token", text: $token)
                            .textContentType(.password)
                        #if os(macOS)
                            .help(provider == .custom ? "API token (optional for local models)" : "API token for the selected AI service")
                        #endif
                    }
                } header: {
                    Text("Provider")
                } footer: {
                    if provider == .apple {
                        Text("Powers smart playlist and queue generation. Apple Intelligence uses Private Cloud Compute and requires no API token.")
                    } else if provider == .custom {
                        Text("Enter the base URL of your OpenAI-compatible API (e.g. http://localhost:11434/v1). The API token is optional for local models.")
                    } else {
                        Text("The API token is required to access the provider's API.")
                    }
                }
            }
            .task(id: provider) {
                guard provider != .apple else {
                    return
                }

                token = provider.token

                let storedModel = UserDefaults.standard.string(forKey: provider.modelKey) ?? ""
                modelID = storedModel.isEmpty ? provider.defaultModel : storedModel
            }
            .onChange(of: token) { _, value in
                guard provider != .apple else {
                    return
                }

                Keychain.set(value, for: provider.tokenKey)
            }
            .onChange(of: modelID) { _, value in
                guard provider != .apple else {
                    return
                }

                UserDefaults.standard.set(value, forKey: provider.modelKey)
            }
        }
    }
}
