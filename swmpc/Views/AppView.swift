//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import SwiftUI

#if os(iOS)
    import LNPopupUI
#endif

enum ViewError: Error {
    case missingData
}

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @AppStorage(Setting.simpleMode) private var simpleMode = false

    #if os(iOS)
        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
    #elseif os(macOS)
        @State private var showQueuePanel = false
        @State private var showClearQueueAlert = false
    #endif

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                Group {
                    @Bindable var boundNavigator = navigator

                    #if os(iOS)
                        TabView(selection: $boundNavigator.category) {
                            ForEach(CategoryDestination.categories) { category in
                                // NOTE: Use SFSafeSymbols version when it is available.
                                // https://github.com/SFSafeSymbols/SFSafeSymbols/issues/138
                                Tab(category.label, systemImage: category.symbol.rawValue, value: category) {
                                    ZStack {
                                        NavigationStack(path: $boundNavigator.path) {
                                            CategoryDestinationView(destination: category)
                                                .navigationDestination(for: ContentDestination.self) { destination in
                                                    ContentDestinationView(destination: destination)
                                                }
                                        }

                                        LoadingView()
                                    }
                                }
                            }
                        }
                        .handleQueueChange()
                        .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                            DetailView(isPopupOpen: $isPopupOpen)
                        }
                        .popupBarProgressViewStyle(.top)
                    #elseif os(macOS)
                        NavigationSplitView {
                            SidebarView()
                                .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                        } content: {
                            NavigationStack(path: $boundNavigator.path) {
                                CategoryDestinationView(destination: navigator.category)
                                    .navigationDestination(for: ContentDestination.self) { destination in
                                        ContentDestinationView(destination: destination)
                                    }
                            }
                            .navigationSplitViewColumnWidth(310)
                            .navigationBarBackButtonHidden(true)
                            .ignoresSafeArea()
                            .overlay(
                                LoadingView()
                            )
                        } detail: {
                            DetailView()
                                .padding(60)
                        }
                        .background(.background)
                        .overlay(alignment: .trailing) {
                            if !simpleMode && showQueuePanel {
                                QueuePanelView()
                                    .frame(width: 350)
                                    .background(.regularMaterial)
                                    .shadow(radius: 10)
                                    .transition(.move(edge: .trailing))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showQueuePanel)
                            }
                        }
                        .toolbar {
                            ToolbarItem {
                                Spacer()
                            }

                            if !simpleMode {
                                if showQueuePanel {
                                    ToolbarItem(placement: .primaryAction) {
                                        Button {
                                            showClearQueueAlert = true
                                        } label: {
                                            Image(systemSymbol: .trash)
                                        }
                                    }
                                }

                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        showQueuePanel.toggle()
                                    } label: {
                                        Image(systemSymbol: showQueuePanel ? .xmarkCircleFill : .musicNoteList)
                                    }
                                }
                            }
                        }
                        .alert("Clear Queue", isPresented: $showClearQueueAlert) {
                            Button("Cancel", role: .cancel) {}
                            AsyncButton("Clear Queue", role: .destructive) {
                                try await mpd.queue.clear()
                            }
                        } message: {
                            Text("This will remove all songs from the queue.")
                        }
                    #endif
                }
                .onAppear {
                    Task {
                        try? await mpd.status.startTrackingElapsed()
                    }
                }
                .onDisappear {
                    mpd.status.stopTrackingElapsed()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 180 + 310 + 650, minHeight: 650)
        #endif
    }
}
