import Foundation

/// 画面の言葉。日本語（元の言葉）と英語をコードに並べ、Localizable.xcstrings（scripts/gen-strings.py が作る）からも引ける形にする。
/// 撮影の場面の名前の後ろに _ja を付けると、英語のシミュレータでも日本語で撮る。
enum Lang {
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }

    static var locale: Locale { Locale(identifier: isJapanese ? "ja_JP" : "en_US") }

    static let english: Bundle? = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
}

/// 言葉を選ぶ（日本語, 英語）
func tr(_ ja: String, _ en: String) -> String {
    if Lang.isJapanese { return ja }
    guard let bundle = Lang.english else { return en }
    let found = bundle.localizedString(forKey: ja, value: nil, table: "Localizable")
    return found == ja ? en : found
}

/// 数などを差し込む言葉（%d・%@）
func trf(_ ja: String, _ en: String, _ args: CVarArg...) -> String {
    String(format: tr(ja, en), locale: Lang.locale, arguments: args)
}
