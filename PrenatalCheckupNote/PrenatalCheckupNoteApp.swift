//
//  PrenatalCheckupNoteApp.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftUI

@main
struct PrenatalCheckupNoteApp: App {
    /// お知らせを押されたときなど、iPhone からの知らせを受け取る（R-46）。
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launch = AppLaunch.start()

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch {
                case .ready(let store):
                    ContentView()
                        .environment(store)
                        // 保存場所を切り替えたら（サンプルデータ）、画面を作り直す。開いていたシートも閉じる。
                        .id(ObjectIdentifier(store))
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
            // 文字はアプリ全体で丸い字体にする（段階 F）。見出しなど役割のある文字は、それぞれ `.maru(...)` で決めている。
            .font(.maru(.body))
            #if DEBUG
            // 開発用の「サンプルデータを表示する」を切り替えたら、その保存場所で開き直す（段階 D）。
            .onChange(of: DeveloperSettings.shared.showsSampleData) { _, showsSampleData in
                launch = AppLaunch.start(showsSampleData: showsSampleData)
            }
            #endif
        }
    }
}
