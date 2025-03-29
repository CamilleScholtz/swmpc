//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import NavigatorUI
import SwiftUI

#if os(iOS)
    import LNPopupUI
#endif

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @State private var destination: SidebarDestination = .albums

    #if os(iOS)
        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
    #endif

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                #if os(iOS)
                    TabView(selection: $destination) {
                        ForEach(SidebarDestination.categories) { category in
                            ManagedNavigationStack {
                                category
                                    .navigationDestination(ContentDestination.self)
                            }
                            .tabItem {
                                Label(category.label, systemSymbol: category.symbol)
                            }
                            .tag(category)
                        }
                        .overlay(
                            LoadingView(destination: $destination)
                        )
                    }
                    .handleQueueChange(destination: $destination)
                    .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                        DetailView()
                    }
                    .popupBarProgressViewStyle(.top)
                #elseif os(macOS)
                    NavigationSplitView {
                        SidebarView(destination: $destination)
                            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                    } content: {
                        ManagedNavigationStack(name: "content") {
                            destination
                                .navigationDestination(ContentDestination.self)
                        }
                        .navigationSplitViewColumnWidth(310)
                        .navigationBarBackButtonHidden(true)
                        .ignoresSafeArea()
                        .overlay(
                            LoadingView(destination: $destination)
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
