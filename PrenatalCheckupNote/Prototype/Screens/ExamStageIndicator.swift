import SwiftUI

/// 健診モードの3段階。要件定義 6章。
enum ExamStage: Int, CaseIterable {
    case before = 1
    case during
    case after

    var title: String {
        switch self {
        case .before: "診察前"
        case .during: "診察中"
        case .after: "診察後"
        }
    }
}

/// 健診モードのいまの段階を示す表示。押して移動するものではない。
///
/// 文字が大きくて3つ並べられないときは、いまの段階だけを「1/3 診察前」の形で出す。
struct ExamStageIndicator: View {
    let current: ExamStage

    var body: some View {
        ViewThatFits(in: .horizontal) {
            allStages
            Text("\(current.rawValue)/\(ExamStage.allCases.count) \(current.title)")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.fill.tertiary))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("健診モード、\(ExamStage.allCases.count)段階中\(current.rawValue)段階目、\(current.title)")
    }

    private var allStages: some View {
        HStack(spacing: 4) {
            ForEach(ExamStage.allCases, id: \.self) { stage in
                Text("\(stage.rawValue) \(stage.title)")
                    .font(.subheadline.weight(stage == current ? .bold : .regular))
                    .foregroundStyle(stage == current ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if stage == current {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.background)
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                        }
                    }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).fill(.fill.tertiary))
    }
}

#Preview {
    VStack(spacing: 16) {
        ExamStageIndicator(current: .before)
        ExamStageIndicator(current: .during)
        ExamStageIndicator(current: .after)
    }
    .padding()
}
