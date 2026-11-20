import SwiftUI

// 色・書体・形を 1 か所で決める。
// 世界：昼は砂浜の白とサンゴ色・ターコイズの海、夜は深い紫のもやの中で作った物だけが琥珀色に光る。
// 書体は丸ゴシック（.rounded）の太い題字と、やわらかい本文。前日までの明朝・洋館・池の青緑とは違う。

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// 昼の島
enum Day {
    static let sand = Color(hex: 0xF8EFDF)
    static let sandDeep = Color(hex: 0xEAD5B2)
    static let paper = Color(hex: 0xFFFAF2)
    static let sea = Color(hex: 0x5CCBC6)
    static let seaDeep = Color(hex: 0x2A9AA3)
    static let foam = Color(hex: 0xDDF5F0)
    static let grass = Color(hex: 0xA8D38E)
    static let grassDeep = Color(hex: 0x78AE66)
    /// 主な色（サンゴ）：accent / soft / deep
    static let coral = Color(hex: 0xF5876F)
    static let coralSoft = Color(hex: 0xFDE3DA)
    static let coralDeep = Color(hex: 0xD45F4A)
    static let ink = Color(hex: 0x40302A)
    static let inkSoft = Color(hex: 0x8C776C)
    static let line = Color(hex: 0xE8D6BC)
    static let sun = Color(hex: 0xFFD27A)
}

/// 夜の島
enum Night {
    static let sky = Color(hex: 0x160D2B)
    static let sea = Color(hex: 0x1E1340)
    static let island = Color(hex: 0x2D2050)
    static let rim = Color(hex: 0x4A3778)
    static let mist = Color(hex: 0x9A84E0)
    static let mistDeep = Color(hex: 0x5E4A9E)
    static let amber = Color(hex: 0xFFC872)
    static let amberDeep = Color(hex: 0xF39B42)
    static let glow = Color(hex: 0xA2F5DF)
    static let danger = Color(hex: 0xFF7389)
    static let text = Color(hex: 0xF5EEFF)
    static let textSoft = Color(hex: 0xB9AEDB)
    static let panel = Color(hex: 0x24183F)
}

enum Fonts {
    /// 題字（ゲームの見出し）
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    /// 見出し
    static func head(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
}

enum Radius {
    static let chip: CGFloat = 10
    static let card: CGFloat = 20
    static let button: CGFloat = 18
    static let sheet: CGFloat = 26
}

extension Material {
    var color: Color {
        switch self {
        case .shell: Color(hex: 0xF4A6A0)
        case .wood: Color(hex: 0xB98A5E)
        case .flower: Color(hex: 0xF7C6DA)
        case .stone: Color(hex: 0xA9B0B8)
        case .glow: Night.glow
        }
    }

    var deep: Color {
        switch self {
        case .shell: Color(hex: 0xD9706A)
        case .wood: Color(hex: 0x82593A)
        case .flower: Color(hex: 0xD9789E)
        case .stone: Color(hex: 0x6F7882)
        case .glow: Color(hex: 0x3FB89A)
        }
    }
}

/// 島の地面のボタン：押すと少し沈む（下辺の厚みが消える）
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color
    var edge: Color
    var text: Color = .white
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Fonts.head(17))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(edge)
                        .offset(y: pressed ? 1 : 4)
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(fill)
                }
            )
            .offset(y: pressed ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// 小さく縮むだけのボタン
struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
