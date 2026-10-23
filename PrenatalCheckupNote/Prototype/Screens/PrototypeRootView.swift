import SwiftUI

/// 段階1（試作A）の入口。健診タブにあたる画面の流れを、メモリ上のデータで動かす。
///
/// 画面遷移は `NavigationStack` の道のり（`path`）で管理する。
/// 状態を切り替えたときに、その状態の最初の画面まで一度に移動できるようにするため。
struct PrototypeRootView: View {
    @State private var store = PrototypeStore()
    @State private var path: [PrototypeRoute] = []
    #if DEBUG
    @State private var isShowingDeveloperMenu = false
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            AppointmentListView()
                .navigationDestination(for: PrototypeRoute.self) { route in
                    destination(for: route)
                }
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
                #endif
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDeveloperMenu) {
            DeveloperMenuView { scenario in
                store.apply(scenario)
                path = store.startPath
            }
        }
        #endif
        // シートの中でも同じデータを読めるように、シートより外側で渡す。
        .environment(store)
    }

    @ViewBuilder
    private func destination(for route: PrototypeRoute) -> some View {
        switch route {
        case .appointment(let appointmentID):
            AppointmentDetailView(appointmentID: appointmentID)
        case .beforeExam:
            PrototypePlaceholderView(title: "診察前")
        case .duringExam:
            PrototypePlaceholderView(title: "診察中")
        case .afterExam:
            PrototypePlaceholderView(title: "健診を完了する")
        case .sharePreview:
            PrototypePlaceholderView(title: "共有プレビュー")
        }
    }
}

/// まだ作っていない画面の代わりに出す画面。段階1の続きのプルリクエストで、ワイヤーどおりの画面に置き換える。
struct PrototypePlaceholderView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("この画面は、段階1の続きで作ります。")
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PrototypeRootView()
}
