//
//  ContentView.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State var search: String = ""
    @FocusState private var isSearchFocused: Bool
        
    var body: some View {
        VStack(alignment: .center) {
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            if let win = NSApp.windows.first(where: { $0.isVisible }) {
                win.makeKeyAndOrderFront(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFocused = true
            }
        }
    }
}

#Preview {
    ContentView()
}
