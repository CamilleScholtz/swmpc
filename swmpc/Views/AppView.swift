//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

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

    #if os(iOS)
        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
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
