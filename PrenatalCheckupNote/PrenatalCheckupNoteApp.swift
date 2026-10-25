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
            Group {
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
            // このアプリは日本語だけ。iPhone の言語や地域の設定によらず、日付と時刻を日本の書き方で出す
            // （例：「Oct 25, 2026」ではなく「2026/10/25」）。日付の計算は、別に `Calendar.japan` で固定している（R-90）。
            // シートもこの下で開くので、同じ書き方になる。
            .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}
