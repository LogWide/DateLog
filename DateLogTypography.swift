import SwiftUI
import UIKit

enum DateLogTypography {
    static let regular = "Pretendard-Regular"
    static let medium = "Pretendard-Medium"
    static let semiBold = "Pretendard-SemiBold"
    static let bold = "Pretendard-Bold"
    static let extraBold = "Pretendard-ExtraBold"
    static let black = "Pretendard-Black"
    static let light = "Pretendard-Light"

    static func configureAppearance() {
        let navigationTitle = UIFont(name: semiBold, size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        let largeNavigationTitle = UIFont(name: bold, size: 34) ?? .systemFont(ofSize: 34, weight: .bold)
        let tabTitle = UIFont(name: medium, size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        let buttonTitle = UIFont(name: semiBold, size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)

        UINavigationBar.appearance().titleTextAttributes = [
            .font: navigationTitle
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: largeNavigationTitle
        ]
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: tabTitle],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: tabTitle],
            for: .selected
        )
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: buttonTitle],
            for: .normal
        )
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: buttonTitle],
            for: .highlighted
        )
    }
}

extension Font {
    static func pretendard(
        size: CGFloat,
        weight: DateLogFontWeight = .regular
    ) -> Font {
        .custom(weight.fontName, size: size)
    }
}

enum DateLogFontWeight {
    case light
    case regular
    case medium
    case semiBold
    case bold
    case extraBold
    case black

    var fontName: String {
        switch self {
        case .light:
            return DateLogTypography.light
        case .regular:
            return DateLogTypography.regular
        case .medium:
            return DateLogTypography.medium
        case .semiBold:
            return DateLogTypography.semiBold
        case .bold:
            return DateLogTypography.bold
        case .extraBold:
            return DateLogTypography.extraBold
        case .black:
            return DateLogTypography.black
        }
    }
}
