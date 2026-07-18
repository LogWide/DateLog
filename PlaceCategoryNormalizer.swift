import Foundation
import SwiftUI
import UIKit

enum PlaceCategoryNormalizer {
    static let defaultCategory = "기타"

    static func categoryName(from rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            return defaultCategory
        }

        if value.contains("음식") ||
            value.contains("식당") ||
            value.contains("레스토랑") ||
            value.contains("분식") ||
            value.contains("한식") ||
            value.contains("중식") ||
            value.contains("일식") ||
            value.contains("양식") ||
            value.contains("이탈리아") ||
            value.contains("고기") ||
            value.contains("치킨") ||
            value.contains("피자") ||
            value.contains("버거") ||
            value.contains("아시아") ||
            value.contains("뷔페") {
            return "식당"
        }

        if value.contains("카페") ||
            value.contains("커피") ||
            value.contains("디저트") ||
            value.contains("베이커리") ||
            value.contains("빵") {
            return "카페"
        }

        if value.contains("술") ||
            value.contains("주점") ||
            value.contains("호프") ||
            value.contains("바") ||
            value.contains("와인") ||
            value.contains("맥주") {
            return "술"
        }

        if value.contains("영화") || value.contains("극장") {
            return "영화"
        }

        if value.contains("쇼핑") ||
            value.contains("백화점") ||
            value.contains("아울렛") ||
            value.contains("마트") ||
            value.contains("상가") {
            return "쇼핑"
        }

        if value.contains("공원") ||
            value.contains("산책") ||
            value.contains("해변") ||
            value.contains("수목원") ||
            value.contains("둘레길") {
            return "산책"
        }

        if value.contains("호텔") ||
            value.contains("모텔") ||
            value.contains("펜션") ||
            value.contains("숙소") ||
            value.contains("리조트") {
            return "숙소"
        }

        if value.contains("드라이브") ||
            value.contains("휴게소") ||
            value.contains("주차") {
            return "드라이브"
        }

        let builtInCategories = [
            "식당",
            "카페",
            "술",
            "영화",
            "쇼핑",
            "산책",
            "숙소",
            "드라이브",
            "기타"
        ]

        if builtInCategories.contains(value) {
            return value
        }

        return defaultCategory
    }

    static func emoji(for category: String) -> String {
        switch categoryName(from: category) {
        case "식당": return "🍽️"
        case "카페": return "☕"
        case "술": return "🍺"
        case "영화": return "🎬"
        case "쇼핑": return "🛍️"
        case "산책": return "🌳"
        case "숙소": return "🏨"
        case "드라이브": return "🚗"
        default: return "📍"
        }
    }

    static func color(for category: String) -> Color {
        switch categoryName(from: category) {
        case "식당":
            return Color(red: 0.93, green: 0.28, blue: 0.24)
        case "카페":
            return Color(red: 0.62, green: 0.38, blue: 0.18)
        case "술":
            return Color(red: 0.56, green: 0.32, blue: 0.84)
        case "영화":
            return Color(red: 0.22, green: 0.40, blue: 0.90)
        case "쇼핑":
            return Color(red: 0.93, green: 0.38, blue: 0.64)
        case "산책":
            return Color(red: 0.18, green: 0.62, blue: 0.34)
        case "숙소":
            return Color(red: 0.06, green: 0.48, blue: 0.62)
        case "드라이브":
            return Color(red: 0.95, green: 0.58, blue: 0.16)
        default:
            return Color(red: 0.42, green: 0.45, blue: 0.52)
        }
    }

    static func uiColor(for category: String) -> UIColor {
        UIColor(color(for: category))
    }
}
