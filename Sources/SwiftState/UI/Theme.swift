import SwiftUI

/// Styling and theme definitions for SwiftState UI components.
/// Uses a premium dark-mode color scheme with neon accents, custom fonts, and layout constants.
public enum SwiftStateUI {
    
    public enum Color {
        public static let background = SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.08)
        public static let cardBackground = SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.4)
        public static let primaryText = SwiftUI.Color.white
        public static let secondaryText = SwiftUI.Color.white.opacity(0.6)
        public static let accentPurple = SwiftUI.Color(red: 0.63, green: 0.35, blue: 1.0)
        public static let accentCyan = SwiftUI.Color(red: 0.0, green: 0.85, blue: 0.95)
        public static let accentGreen = SwiftUI.Color(red: 0.0, green: 0.90, blue: 0.46)
        public static let border = SwiftUI.Color.white.opacity(0.1)
        public static let activeHighlight = SwiftUI.Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.8)
    }
    
    public enum Font {
        public static let codeTitle = SwiftUI.Font.system(size: 14, weight: .bold, design: .monospaced)
        public static let codeBody = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        public static let codeCaption = SwiftUI.Font.system(size: 10, weight: .light, design: .monospaced)
        public static let heading = SwiftUI.Font.system(size: 16, weight: .black, design: .rounded)
    }
    
    public enum Layout {
        public static let cornerRadius: CGFloat = 16
        public static let padding: CGFloat = 16
        public static let borderSize: CGFloat = 1
    }
}
