import SwiftUI

/// はじめにの 1 枚目「ようこそ」（要件定義 5.11 の R-112、キャンバスの見本 `OnboardC1.dc.html`）。
///
/// 上の空色のところにアプリのアイコンの絵を大きく出し、下の地の色のところに、3 つのタブでできることを並べる。
/// いちばん下のボタンの文と動きは、使う側が決める（はじめにでは「つぎへ」。使い方からもう一度見るときは「閉じる」）。
struct WelcomePage: View {
    /// いちばん下のボタンの文。
    let buttonTitle: String
    /// ページの点（2 枚のうちの 1 枚目）を出すか。はじめにの中だけで出す。
    var showsPageDots = true
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // 画面に収まるときは、余った高さを紹介の間に配って、画面いっぱいに広げる（ScrollView の中では広げられないため）。
        // 文字を大きくして収まらないときは、詰めた形をスクロールで見せる。
        // 最初は紹介が上に寄り、下に大きな空きが残った（開発者の指摘）。
        ViewThatFits(in: .vertical) {
            content(spreads: true)
            ScrollView {
                content(spreads: false)
            }
            // 引っぱっても動かさない（下で空色がのぞかないように）。
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColors.welcomeSky)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 14) {
                if showsPageDots {
                    OnboardingPageDots(current: 0)
                }
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.maru(.headline))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                // ダークでは明るい青のボタンになるので、文字は濃い紺にする（段階 F）。
                .foregroundStyle(AppColors.onAccent)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(AppColors.background)
            // 文字サイズ最大でも、下の帯が画面の多くを占めないようにする（段階 F2 と同じ）。
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    /// 上の空色のところ。白い丸を背景に置き、アイコンと「ようこそ」を出す。
    /// 見本にあったキラキラとハートの飾りは、開発者の指摘で置かない（R-115）。
    private var hero: some View {
        VStack(spacing: 0) {
            Image("WelcomeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white, lineWidth: 5)
                }
                .shadow(color: Color(red: 0.18, green: 0.38, blue: 0.6).opacity(0.2), radius: 11, y: 8)
                .accessibilityLabel("妊婦さんと先生がノートを見ている絵")
                .padding(.bottom, 24)

            Text("妊婦健診ノートへ")
                .font(.maru(.subheadline))
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
            Text("ようこそ")
                .font(.maru(.largeTitle))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .background {
            bubbles
        }
    }

    /// 空色の上の、うすい白い丸。飾りなので、読み上げない。
    private var bubbles: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let opacity = colorScheme == .dark ? 0.08 : 0.5
            ZStack {
                Circle().frame(width: 88, height: 88).position(x: 30, y: height * 0.3)
                Circle().frame(width: 108, height: 108).position(x: width - 22, y: height * 0.12)
                Circle().frame(width: 56, height: 56).position(x: width - 38, y: height * 0.86)
                Circle().frame(width: 36, height: 36).position(x: 52, y: height * 0.9)
            }
            .foregroundStyle(.white.opacity(opacity))
        }
        .accessibilityHidden(true)
    }

    /// 上の空色のところと、下の地の色のところ。`spreads` が true なら、余った高さを間に配る。
    private func content(spreads: Bool) -> some View {
        VStack(spacing: 0) {
            if spreads {
                Spacer(minLength: 0)
                    .frame(maxHeight: 24)
            }
            hero
            features(spreads: spreads)
                // 下の地の色が画面の下まで続くようにする。中身の高さだけ塗ると、その下に空色がのぞいた。
                // 地の色を下に大きくはみ出させて塗り、はみ出した分は画面の枠で切る。
                .background(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
                        .fill(AppColors.background)
                        .padding(.bottom, -1000)
                }
        }
        .clipped()
    }

    /// 下の地の色のところの中身。3 つのタブの紹介を並べる。
    private func features(spreads: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(WelcomeFeature.all.enumerated()), id: \.element.title) { index, feature in
                if index > 0 {
                    // 紹介どうしの間。広げるときは、余った高さを配る（広げすぎないよう上限を付ける）。
                    if spreads {
                        Spacer(minLength: 20)
                            .frame(maxHeight: 44)
                    } else {
                        Spacer(minLength: 20)
                            .frame(height: 20)
                    }
                }
                WelcomeFeatureRow(feature: feature)
            }
            if spreads {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「ようこそ」の 1 つのタブの紹介。タブの見出しと同じ印と色の四角、見出し、箇条書き。
private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: kind.systemImage)
                .font(.title2)
                .foregroundStyle(kind.iconColor)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(kind.tint))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.maru(.title3))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                ForEach(feature.bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("・")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(bullet)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.maru(.subheadline))
                    // 箇条書きどうしの間も少しあける。
                    .padding(.bottom, bullet == feature.bullets.last ? 0 : 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 読み上げでは、見出しと箇条書きを 1 つにまとめて読む。
        .accessibilityElement(children: .combine)
    }

    private var kind: ScreenHeader.Kind {
        switch feature.tab {
        case .next: .next
        case .todo: .todo
        case .past: .past
        }
    }
}

/// はじめにの 2 枚のうち、いまどちらを見ているかの点。今の点だけ横に長い。飾りなので、読み上げない。
struct OnboardingPageDots: View {
    let current: Int
    var count = 2

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: index == current ? 20 : 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
