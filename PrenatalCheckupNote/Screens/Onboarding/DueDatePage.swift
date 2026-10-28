import SwiftUI

/// はじめにの 2 枚目「出産予定日」（要件定義 5.11 の R-113、キャンバスの見本 `OnboardC2.dc.html`）。
///
/// 入れる中身（出産予定日・いまの週数から計算・あとで入れる）は、2 枚に分ける前のはじめにと同じ（`DueDateInputRows`）。
struct DueDatePage: View {
    @Binding var entry: DueDateEntry
    /// 1 枚目に戻る。
    let back: () -> Void
    /// はじめにを終える。予定日を入れずに始めるときは nil。
    let finish: (CalendarDay?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    heading
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                Section {
                    // 2 行を 1 つの行にまとめる（別々の行にすると、行の間が見本より大きくあいた）。
                    VStack(alignment: .leading, spacing: 10) {
                        BenefitRow(systemImage: "heart.fill", color: AppColors.pink, text: "今日の妊娠週数を表示します")
                        BenefitRow(systemImage: "calendar", color: .accentColor, text: "次の健診の日付の目安を、時期に合った間隔で入れます")
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppColors.skyCard)

                Section {
                    DueDateInputRows(entry: $entry)
                } footer: {
                    Text("あとから右上の設定で入れたり、直したりできます。記録はこの iPhone の中だけに保存します。")
                        .font(.maru(.footnote))
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("1 枚目に戻る")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingPageDots(current: 1)
                        .padding(.bottom, 6)
                    Button {
                        finish(entry.dueDate(today: CalendarDay(.now)))
                    } label: {
                        Text("はじめる")
                            .font(.maru(.headline))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    // ダークでは明るい青のボタンになるので、文字は濃い紺にする（段階 F）。
                    .foregroundStyle(AppColors.onAccent)
                    .controlSize(.large)
                    // 出産予定日が決まるまでは押せない（「あとで入れる」なら入れずに始められる）。
                    .disabled(entry.dueDate(today: CalendarDay(.now)) == nil)

                    Button {
                        finish(nil)
                    } label: {
                        Text("あとで入れる")
                            .font(.maru(.callout))
                    }
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(AppColors.background)
                // 文字サイズ最大でも、下の帯が画面の多くを占めないようにする（段階 F2）。
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
    }

    /// カレンダーの絵と見出し。
    private var heading: some View {
        VStack(spacing: 8) {
            CalendarHeartIcon()
                .frame(width: 120, height: 120)
                .background(Circle().fill(AppColors.headerTintPink))
                .accessibilityHidden(true)
                .padding(.bottom, 12)

            Text("出産予定日を入れましょう")
                .font(.maru(.title2))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("入れなくても、すべての機能を使えます。")
                .font(.maru(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// 白いカレンダーの中にハートがある絵（見本と同じ形）。
///
/// iOS の標準のカレンダーの印は日付のます目が入っていて、ハートと重なって見本と違って見えた（開発者の指摘）ので、形を描く。
/// ピンクの丸はダークでも明るいままなので、線は決まった青にする。
private struct CalendarHeartIcon: View {
    private let line: CGFloat = 3.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppColors.headerIconBlue, lineWidth: line)
            // 上の帯の線。
            Rectangle()
                .fill(AppColors.headerIconBlue)
                .frame(height: line)
                .padding(.horizontal, line / 2)
                .offset(y: -11)
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.91, green: 0.52, blue: 0.61))
                .offset(y: 6)
        }
        .frame(width: 60, height: 54)
        // 上の 2 つの留め具。
        .overlay(alignment: .top) {
            HStack(spacing: 22) {
                Capsule().fill(AppColors.headerIconBlue).frame(width: line, height: 12)
                Capsule().fill(AppColors.headerIconBlue).frame(width: line, height: 12)
            }
            .offset(y: -6)
        }
    }
}

/// 出産予定日を入れるとできることの 1 行。
private struct BenefitRow: View {
    let systemImage: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .font(.maru(.subheadline))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
