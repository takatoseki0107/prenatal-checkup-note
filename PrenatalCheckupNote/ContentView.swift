//
//  ContentView.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftData
import SwiftUI

/// アプリの一番下の画面。下の 2 つのタブ「次の健診」「これまでの健診」と、シートを受け持つ（要件定義 v0.4 の 4 章）。
///
/// シートはここで 1 か所にまとめて開く。失敗の知らせは、シートを開いていないときだけここで出し、
/// 開いているときはシートの側で出す（`noteErrorAlert`）。
struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("次の健診", systemImage: "list.bullet.clipboard", value: AppRouter.Tab.next) {
                NavigationStack {
                    NextCheckupScreen()
                }
            }
            Tab("これまでの健診", systemImage: "book.closed", value: AppRouter.Tab.past) {
                NavigationStack {
                    PastCheckupsScreen()
                }
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .addQuestion:
                AddQuestionSheet()
            case .editQuestion(let questionID):
                EditQuestionSheet(questionID: questionID)
            case .writeMemo:
                WriteMemoSheet()
            case .nextCheckup:
                NextCheckupSheet()
            case .bringItems:
                BringItemsSheet()
            case .settings:
                SettingsView()
            }
        }
        .noteErrorAlert(store, isActive: router.sheet == nil)
        .environment(router)
    }
}

#Preview {
    let container = try! AppDataStore.makeInMemoryContainer()
    let service = NoteService(context: ModelContext(container))
    ContentView()
        .environment(NoteStore(container: container, service: service))
}
