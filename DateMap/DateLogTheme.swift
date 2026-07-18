import SwiftUI

enum DateLogTheme: String, CaseIterable, Identifiable {
    case pink
    case black
    case navy
    case cream

    var id: Self { self }

    var title: String {
        switch self {
        case .pink:
            return "핑크"
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
        case .pink:
            return Color(
                red: 0.93,
                green: 0.32,
                blue: 0.58
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
        case .pink:
            return Color(
                red: 0.78,
                green: 0.18,
                blue: 0.43
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

    var backgroundColor: Color {
        Color(uiColor: .systemBackground)
    }

    var cardBackgroundColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    var primaryTextColor: Color {
        .primary
    }

    var secondaryTextColor: Color {
        .secondary
    }

    var navigationTextColor: Color {
        switch self {
        case .cream:
            return Color(
                red: 0.20,
                green: 0.16,
                blue: 0.09
            )
        case .pink, .black, .navy:
            return .white
        }
    }

    var navigationColorScheme: ColorScheme {
        switch self {
        case .cream:
            return .light
        case .pink, .black, .navy:
            return .dark
        }
    }

    var color: Color {
        switch self {
        case .cream:
            return Color(
                red: 0.98,
                green: 0.94,
                blue: 0.84
            )
        case .pink, .black, .navy:
            return primaryColor
        }
    }

    var accentColor: Color {
        secondaryColor
    }
}
