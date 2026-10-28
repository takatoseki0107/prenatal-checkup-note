import SwiftUI

/// 「使い方」のシート（要件定義 5.12、キャンバスの見本 `HelpSheetNext.dc.html`・`HelpSheetTrouble.dc.html`）。
///
/// 各タブの右上の「？」で開く。最初は、押した画面のタブの説明を出す（R-117）。
/// 上のボタンで「健診予定・タスク・健診の記録・困ったとき」を切り替える。文は `HelpContent` に持つ。
/// 使い方がわからなくなったときに見返せるように、という開発者の提案で足した。
struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var topic: HelpTopic
    /// 「はじめにの画面をもう一度見る」で、ようこその画面を出しているか（R-120）。
    @State private var showsWelcome = false

    init(topic: HelpTopic) {
        _topic = State(initialValue: topic)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if topic == .trouble {
                        ForEach(HelpContent.questions, id: \.question) { item in
                            QuestionCard(item: item)
                        }
                    } else {
                        ForEach(Array(HelpContent.steps(for: topic).enumerated()), id: \.element.title) { index, step in
                            StepCard(number: index + 1, step: step, topic: topic)
                        }
                    }
                    if let tip = HelpContent.tip(for: topic) {
                        TipCard(text: tip)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppColors.background)
            .navigationTitle("使い方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                topicPicker
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    showsWelcome = true
                } label: {
                    Text("はじめにの画面をもう一度見る")
                        .font(.maru(.subheadline))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(AppColors.card))
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.background)
                // 文字サイズ最大でも、下の帯が画面の多くを占めないようにする（段階 F2 と同じ）。
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        // 1 枚目「ようこそ」だけを見せる。予定日の入力はせず、データは何も変えない（予定日は設定で直すため）。
        .fullScreenCover(isPresented: $showsWelcome) {
            WelcomePage(buttonTitle: "閉じる", showsPageDots: false) {
                showsWelcome = false
            }
        }
    }

    /// 上の切り替え。選んでいるものだけ青く塗る。
    private var topicPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HelpTopic.allCases, id: \.self) { item in
                    Button {
                        topic = item
                    } label: {
                        Text(item.title)
                            .font(.maru(.subheadline))
                            .foregroundStyle(item == topic ? AppColors.onAccent : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(item == topic ? Color.accentColor : AppColors.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == topic ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.background)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// 番号つきの手順の 1 つ。番号の丸は、タブの見出しと同じ色の四角の色にする。
private struct StepCard: View {
    let number: Int
    let step: HelpStep
    let topic: HelpTopic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.maru(.subheadline))
                .fontWeight(.bold)
                .foregroundStyle(numberColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.maru(.headline))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(step.body)
                    .font(.maru(.footnote))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(step.title)。\(step.body)")
    }

    private var tint: Color {
        switch topic {
        case .next, .trouble: AppColors.headerTintPink
        case .todo: AppColors.headerTintYellow
        case .past: AppColors.headerTintSky
        }
    }

    private var numberColor: Color {
        switch topic {
        case .next, .trouble: AppColors.headerIconBlue
        case .todo: AppColors.headerIconYellow
        case .past: AppColors.headerIconSky
        }
    }
}

/// 困ったときの、問いと答えの 1 組。
private struct QuestionCard: View {
    let item: HelpQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Q")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(item.question)
                    .foregroundStyle(.primary)
            }
            .font(.maru(.subheadline))
            .fontWeight(.bold)
            Text(item.answer)
                .font(.maru(.footnote))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.card))
        .accessibilityElement(children: .combine)
    }
}

/// 手順の下のひとことのコツ。空色の地に電球の印。
private struct TipCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.maru(.footnote))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.skyCard))
    }
}
