import SwiftUI

extension Color {
    /// 画面外周のネオンラインに使う、鮮やかで明るいシアン。
    static let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
}

/// 画面全体の最も外側を薄く縁取るネオンライン。タップを奪わないよう表示専用。
struct NeonScreenBorder: View {
    var body: some View {
        Rectangle()
            .strokeBorder(Color.neonCyan, lineWidth: 1)
            .shadow(color: Color.neonCyan.opacity(0.9), radius: 4)
            .shadow(color: Color.neonCyan.opacity(0.5), radius: 10)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
