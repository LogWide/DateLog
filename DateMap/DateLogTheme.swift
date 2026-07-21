import SwiftUI
import UIKit

enum DateLogTheme: String, CaseIterable, Identifiable {
    case standard
    case black
    case navy
    case cream

    var id: Self { self }

    var title: String {
        switch self {
        case .standard:
            return "기본"
        case .black:
            return "블랙"
        case .navy:
            return "네이비"
        case .cream:
            return "크림"
        }
    }

    var primaryColor: Color {
        switch self {
        case .standard:
            // 원색 핑크를 눌러 부드럽게 만든 로즈 핑크
            return Color(
                red: 0.92,
                green: 0.47,
                blue: 0.61
            )
        case .black:
            return Color(
                red: 0.06,
                green: 0.06,
                blue: 0.07
            )
        case .navy:
            return Color(
                red: 0.05,
                green: 0.12,
                blue: 0.24
            )
        case .cream:
            return Color(
                red: 0.30,
                green: 0.28,
                blue: 0.16
            )
        }
    }

    var secondaryColor: Color {
        switch self {
        case .standard:
            return Color(
                red: 0.80,
                green: 0.35,
                blue: 0.48
            )
        case .black:
            return Color(
                red: 0.42,
                green: 0.42,
                blue: 0.46
            )
        case .navy:
            return Color(
                red: 0.12,
                green: 0.28,
                blue: 0.46
            )
        case .cream:
            return Color(
                red: 0.13,
                green: 0.29,
                blue: 0.20
            )
        }
    }

    /// 모든 탭·메뉴 공통으로 깔리는 아주 은은한 파스텔 배경
    var backgroundColor: Color {
        switch self {
        case .standard:
            return Color(
                red: 1.00,
                green: 0.978,
                blue: 0.945
            )
        case .black:
            return Color(
                red: 0.965,
                green: 0.962,
                blue: 0.972
            )
        case .navy:
            return Color(
                red: 0.955,
                green: 0.966,
                blue: 0.985
            )
        case .cream:
            return Color(
                red: 0.995,
                green: 0.982,
                blue: 0.948
            )
        }
    }

    /// 파스텔 배경 위에 올라가는 카드 표면색
    var cardBackgroundColor: Color {
        Color.white
    }

    /// 박음질 스티치(실) 색상 — 카드 테두리용
    var stitchColor: Color {
        primaryColor.opacity(0.34)
    }

    var primaryTextColor: Color {
        .primary
    }

    var secondaryTextColor: Color {
        .secondary
    }

    /// 헤더(네비게이션 바)가 흰색이므로 그 위 텍스트·아이콘은 어두운 중성색
    var navigationTextColor: Color {
        Color(
            red: 0.22,
            green: 0.20,
            blue: 0.19
        )
    }

    var navigationColorScheme: ColorScheme {
        .light
    }

    /// primaryColor 배경 헤더에서의 상태바·타이틀 색상 스킴
    var onPrimaryColorScheme: ColorScheme {
        .dark
    }

    /// primaryColor 배경 위에 올리는 텍스트 색
    var onPrimaryTextColor: Color {
        .white
    }

    /// 헤더(네비게이션 바) 배경색
    var color: Color {
        .white
    }

    var accentColor: Color {
        secondaryColor
    }

    // MARK: - 포인트색 ↔ 배경색 대비 보정

    private static func luminance(of color: Color) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    /// 포인트색과 배경색의 명도 차가 충분해 서로 글자색으로 써도 되는지
    private var hasDistinctPrimaryBackground: Bool {
        abs(
            Self.luminance(of: primaryColor) - Self.luminance(of: backgroundColor)
        ) >= 0.32
    }

    /// 배경색 바탕 위에 올리는 포인트색 글자.
    /// 두 색의 명도가 비슷하면 흰색/검은색으로 대체한다.
    var primaryOnBackgroundTextColor: Color {
        if hasDistinctPrimaryBackground {
            return primaryColor
        }

        return Self.luminance(of: backgroundColor) > 0.5 ? .black : .white
    }

    /// 포인트색 바탕 위에 올리는 배경색 글자.
    /// 두 색의 명도가 비슷하면 흰색/검은색으로 대체한다.
    var backgroundOnPrimaryTextColor: Color {
        if hasDistinctPrimaryBackground {
            return backgroundColor
        }

        return Self.luminance(of: primaryColor) > 0.5 ? .black : .white
    }
}
