import SwiftUI

// MARK: - ポムポムプリンテーマ
extension Color {
    // メインカラーパレット
    static let pompomYellow = Color(hex: "FFD93D")      // ポムポムプリンの黄色
    static let pompomBrown = Color(hex: "8B6914")       // ベレー帽のブラウン
    static let pompomCream = Color(hex: "FFF9F2")       // クリーム背景色
    static let pompomText = Color(hex: "331708")        // テキストカラー（ダークブラウン）
    static let pompomTextSecondary = Color(hex: "7A5C3E") // 補助テキスト
    static let pompomAccent = Color(hex: "F5A623")      // アクセントカラー（オレンジイエロー）
    static let pompomPink = Color(hex: "FFB5BA")        // ピンクアクセント
    static let pompomCardBg = Color(hex: "FFFDFB")      // カード背景

    // セマンティックカラー
    static let themeBackground = pompomCream
    static let themeText = pompomText
    static let themeTextSecondary = pompomTextSecondary
    static let themeAccent = pompomYellow
    static let themeTint = pompomBrown

    // エラー・成功
    static let error = Color(hex: "E57373")             // 柔らかいエラー色
    static let success = Color(hex: "81C784")           // 柔らかい成功色

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// アクセントカラーの設定
extension ShapeStyle where Self == Color {
    static var accent: Color { Color.themeAccent }
}
