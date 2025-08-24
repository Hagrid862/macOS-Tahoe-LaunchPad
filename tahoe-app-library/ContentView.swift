//
//  ContentView.swift
//  tahoe-app-library
//
//  Created by Nikodem Okroj on 24/8/25.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @State var search: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var allApps: [AppInfo] = []
    @State private var cancellables: Set<AnyCancellable> = []
        
    var body: some View {
        VStack(alignment: .center) {
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .frame(maxWidth: 300)
            List(filteredApps) { app in
                HStack(spacing: 10) {
                    let nsImage = NSWorkspace.shared.icon(forFile: app.url.path)
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                    Text(app.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: 600, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top)
        .task {
            await loadApps()
        }
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

    private var filteredApps: [AppInfo] {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allApps }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func loadApps() async {
        let apps = await AppDiscovery.loadAllApplications()
        await MainActor.run {
            self.allApps = apps
        }
    }
}

#Preview {
    ContentView()
}
