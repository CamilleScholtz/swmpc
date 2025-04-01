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
                @Bindable var boundNavigator = navigator

                #if os(iOS)
                    TabView(selection: $boundNavigator.category) {
                        ForEach(SidebarDestination.categories) { category in
                            DestinationsView()
                                .tabItem {
                                    Label(category.label, systemSymbol: category.symbol)
                                }
                                .tag(category)
                        }
                        .overlay(
                            LoadingView()
                        )
                    }
                    .handleQueueChange()
                    .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                        DetailView()
                    }
                    .popupBarProgressViewStyle(.top)
                #elseif os(macOS)
                    NavigationSplitView {
                        SidebarView()
                            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                    } content: {
                        DestinationsView()
                            .navigationSplitViewColumnWidth(310)
                            .overlay(
                                LoadingView()
                            )
                    } detail: {
                        ViewThatFits {
                            DetailView()
                        }
                        .padding(60)
                    }
                    .background(.background)
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 180 + 310 + 650, minHeight: 650)
        .toolbar {
            Color.clear
        }
        #endif
    }
}
