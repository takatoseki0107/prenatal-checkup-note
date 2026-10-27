import SwiftUI

/// 各タブの画面のいちばん上の見出し（段階 F、題名の見た目の案 A＋C）。
///
/// 題名の左に、タブと同じ印をやわらかい色の角丸の四角に入れて添え（案 A）、題名の下に蛍光ペンのような色を敷いて、
/// 右上にキラッとした飾りを付ける（案 C）。題名の下には一言を出す（文は `ScreenHeaderText`）。
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

        var sparkColor: Color {
            switch self {
            case .next: AppColors.pink
            case .todo: AppColors.star
            case .past: AppColors.headerSparkSky
            }
        }
    }

    let kind: Kind
    let title: String
    let subtitle: String
    /// 一言の前にピンクのハートを付けるか（今日の妊娠週数のとき）。
    var showsHeart = false

    @Environment(\.dynamicTypeSize) private var typeSize
    /// 蛍光ペンの太さ。文字の大きさに合わせて太くする。
    @ScaledMetric(relativeTo: .title) private var markerHeight: CGFloat = 12

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
                    // 題名の下半分に、少し傾けた蛍光ペンの色を敷く。
                    .background(alignment: .bottom) {
                        Capsule()
                            .fill(kind.marker)
                            .frame(height: markerHeight)
                            .padding(.horizontal, -4)
                            .offset(y: -markerHeight * 0.15)
                            .rotationEffect(.degrees(-1.2))
                    }
                    .overlay(alignment: .topTrailing) {
                        if !typeSize.isAccessibilitySize {
                            sparkles
                        }
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
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    /// 題名の右上のキラッとした飾り（大きいのと小さいのを 1 つずつ）。飾りなので、読み上げない。
    private var sparkles: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: "sparkle")
                .font(.system(size: 15, weight: .bold))
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
                .offset(x: 12, y: 18)
        }
        .foregroundStyle(kind.sparkColor)
        .offset(x: 24, y: -6)
        .accessibilityHidden(true)
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
            // 見出しの高さ（およそ 60 ポイント）より下にずらしたら、隠れたとみなす。
            geometry.contentOffset.y + geometry.contentInsets.top > 60
        } action: { _, isPast in
            action(isPast)
        }
    }
}
