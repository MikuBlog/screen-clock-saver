//
//  StudioApp.swift
//  「翻页时钟」设置应用入口
//

import SwiftUI

@main
struct StudioApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 660)
        }
        .windowResizability(.contentSize)
    }
}
