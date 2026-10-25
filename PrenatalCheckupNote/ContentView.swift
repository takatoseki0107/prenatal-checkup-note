//
//  ContentView.swift
//  PrenatalCheckupNote
//
//  Created by 関貴斗 on 2026/10/23.
//

import SwiftData
import SwiftUI

/// アプリの最初の画面。
///
/// 段階 A では、保存の土台を実際に操作して確かめる、確認用の画面を出す（要件定義 v0.4 の 9 章「確認点」）。
/// 「次の健診」「これまでの健診」の 2 つのタブは段階 B で作る。
struct ContentView: View {
    #if DEBUG
    @State private var isShowingDeveloperMenu = false
    #endif

    var body: some View {
        NavigationStack {
            CheckpointView()
                #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingDeveloperMenu = true
                        } label: {
                            Label("開発用", systemImage: "hammer")
                        }
                    }
                }
                .sheet(isPresented: $isShowingDeveloperMenu) {
                    DeveloperMenuView()
                }
                #endif
        }
    }
}

#Preview {
    let container = try! AppDataStore.makeInMemoryContainer()
    let service = NoteService(context: ModelContext(container))
    ContentView()
        .environment(NoteStore(container: container, service: service))
}
