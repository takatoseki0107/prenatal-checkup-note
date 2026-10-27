import SwiftUI

/// 各タブの画面のいちばん上の見出し（段階 F、題名の見た目の案 A＋C）。
///
/// 題名の左に、タブと同じ印をやわらかい色の角丸の四角に入れて添え（案 A）、題名の下に蛍光ペンのような細い線を引く（案 C）。
/// 案 C の右上のキラッとした飾りは、画面で見て開発者がなくてよいとした。題名の下には一言を出す（文は `ScreenHeaderText`）。
/// iOS 標準の大きな題名だけでは質素だった（開発者の希望）。見本の 3 案から、ダークモードでも崩れにくい A に C を混ぜた。
/// 一覧（List）のいちばん上の行として置き、上の帯の題名は `screenHeaderTitle(_:isShown:)` で出し分ける。
struct ScreenHeader: View {
    /// どのタブの見出しか。印と色が決まる。
    enum Kind {
        case next
        case todo
        case past

        var systemImage: String {
            switch self {
            case .next: "list.bullet.clipboard"
            case .todo: "checklist"
            case .past: "book.closed"
            }
        }

        var tint: Color {
            switch self {
            case .next: AppColors.headerTintPink
            case .todo: AppColors.headerTintYellow
            case .past: AppColors.headerTintSky
            }
        }

        var marker: Color {
            switch self {
            case .next: AppColors.headerMarkerPink
            case .todo: AppColors.headerMarkerYellow
            case .past: AppColors.headerMarkerSky
            }
        }

        var iconColor: Color {
            switch self {
            case .next: Color.accentColor
            case .todo: AppColors.headerIconYellow
            case .past: AppColors.headerIconSky
            }
        }

    }

    let kind: Kind
    let title: String
    let subtitle: String
    /// 一言の前にピンクのハートを付けるか（今日の妊娠週数のとき）。
    var showsHeart = false

    /// 蛍光ペンの太さ。文字の大きさに合わせて太くする。
    /// 最初は 12 ポイントで太すぎた（開発者の指摘）ので、半分以下にして、文字の下のほうに引く。
    @ScaledMetric(relativeTo: .title) private var markerHeight: CGFloat = 5

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.title2)
                .foregroundStyle(kind.iconColor)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(kind.tint))
                // 文字サイズが大きくても、印の四角は大きくしすぎない（段階 F2 と同じ考え方）。
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.maru(.title))
                    .foregroundStyle(.primary)
                    // 題名の下のほうに、少し傾けた細い蛍光ペンの線を引く。
                    .background(alignment: .bottom) {
                        Capsule()
                            .fill(kind.marker)
                            .frame(height: markerHeight)
                            .padding(.horizontal, -3)
                            .offset(y: markerHeight * 0.2)
                            .rotationEffect(.degrees(-1.2))
                    }
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 4) {
                    if showsHeart {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppColors.pink)
                            .accessibilityHidden(true)
                    }
                    Text(subtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.maru(.subheadline))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 一覧の行は、まわりの角を丸く切り取られる。印の四角が行の左はしにあると、四角の左の角まで切られて形がくずれた
        // （実機で開発者が見つけた）。上下と左に少し余白をとって、四角が切り取られる角にかからないようにする。
        .padding(.vertical, 10)
        .padding(.leading, 4)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }
}

extension View {
    /// 見出し（`ScreenHeader`）を置いた画面の、上の帯の題名。
    ///
    /// 見出しが見えている間は、上の帯に題名を出さない（同じ題名が 2 つ並ばないように）。
    /// 一覧を下にずらして見出しが隠れたら、上の帯の真ん中に小さく題名を出す（いまどの画面かわかるように）。
    /// `isShown` は、一覧をどれだけずらしたかで画面の側が決める（`onScrolledPastHeader`）。
    func screenHeaderTitle(_ title: String, isShown: Bool) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.maru(.headline))
                        .opacity(isShown ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: isShown)
                        .accessibilityHidden(!isShown)
                }
            }
    }

    /// 一覧を、見出しが隠れるくらい下にずらしたかを知らせる。
    func onScrolledPastHeader(_ action: @escaping (Bool) -> Void) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            // 見出しがほぼ隠れるくらい（90 ポイント）下にずらしたら、隠れたとみなす。
            // 見出しに上下の余白を足したあと、60 のままだと、見出しがまだ半分見えているうちに上の帯の題名も出て、
            // 題名が 2 つ重なって見えた（実機で見つけた）。
            geometry.contentOffset.y + geometry.contentInsets.top > 90
        } action: { _, isPast in
            action(isPast)
        }
    }
}
