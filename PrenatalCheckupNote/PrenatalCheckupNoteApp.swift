//
//  PrenatalCheckupNoteApp.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftUI

@main
struct PrenatalCheckupNoteApp: App {
    @State private var launch = AppLaunch.start()

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let store):
                ContentView()
                    .environment(store)
            case .failed(let message):
                ContentUnavailableView(
                    "データを開けませんでした",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
    }
}
