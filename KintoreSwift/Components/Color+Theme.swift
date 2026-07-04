//
//  Color+Theme.swift

import SwiftUI
import UIKit

extension Color {
    static let bg = Color.black
    static let card = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let cardSub = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let accent = Color(red: 52/255, green: 199/255, blue: 89/255)
}

// MARK: - ゲームテーマパレット（Home画面基準の共通トンマナ）

extension Color {
    /// メインアクセント（金）
    static let gameGold = Color(red: 1.0, green: 0.8, blue: 0.35)
    static let gameGoldDeep = Color(red: 0.96, green: 0.6, blue: 0.18)
    /// サブアクセント（紫・青）
    static let gamePurple = Color(red: 0.6, green: 0.42, blue: 0.98)
    static let gamePurpleLight = Color(red: 0.78, green: 0.66, blue: 1.0)
    static let gameBlue = Color(red: 0.42, green: 0.64, blue: 1.0)
}

extension UIColor {
    /// FSCalendarなどUIKit側で使うゲームテーマ色
    static let gameGoldUI = UIColor(red: 1.0, green: 0.8, blue: 0.35, alpha: 1.0)
    static let gameGoldDeepUI = UIColor(red: 0.96, green: 0.6, blue: 0.18, alpha: 1.0)
    static let gamePurpleUI = UIColor(red: 0.6, green: 0.42, blue: 0.98, alpha: 1.0)
}
