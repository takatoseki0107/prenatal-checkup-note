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
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    private let notificationTaps = NotificationTapRelay.shared

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
            case .memo(let memoID):
                MemoDetailSheet(memoID: memoID)
            case .settings:
                SettingsView()
            case .shareQuestions:
                ShareQuestionsSheet()
            }
        }
        // 初めて開いたときだけ「はじめに」を出す。終えると `needsOnboarding` が false になり、閉じる。
        .fullScreenCover(isPresented: Binding { store.needsOnboarding } set: { _ in }) {
            OnboardingView()
        }
        .noteErrorAlert(store, isActive: router.sheet == nil && !store.needsOnboarding)
        // 前面に戻ったとき（設定アプリで通知を許可して戻ったときを含む）に、お知らせを合わせ直す（S-06）。
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.reminders?.requestSync()
            }
        }
        // お知らせを押されたら「次の健診」を開く（R-46）。押されて起動したときは、画面ができた時点で印が置いてあるので、最初にも見る。
        // シートを開いていたときは閉じない。直している途中の内容が消えないように。シートを閉じると「次の健診」が見える。
        .onChange(of: notificationTaps.opensNextCheckup, initial: true) { _, opens in
            if opens {
                router.selectedTab = .next
                notificationTaps.didOpenNextCheckup()
            }
        }
        .environment(router)
    }
}

#Preview {
    let container = try! AppDataStore.makeInMemoryContainer()
    let service = NoteService(context: ModelContext(container))
    ContentView()
        .environment(NoteStore(container: container, service: service))
}
