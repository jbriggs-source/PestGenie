import SwiftUI
import UIKit

/// PestGenie Design System
/// A comprehensive design system providing consistent visual language across the app.
/// Follows iOS Human Interface Guidelines and accessibility best practices.
struct PestGenieDesignSystem {

    // MARK: - Color Tokens

    /// Brand colors representing PestGenie's visual identity
    struct Colors {

        // MARK: - Brand Colors
        static let primary = Color(red: 0.0, green: 0.5, blue: 0.3) // Forest Green
        static let primaryLight = Color(red: 0.1, green: 0.7, blue: 0.4) // Light Forest Green
        static let primaryDark = Color(red: 0.0, green: 0.3, blue: 0.2) // Dark Forest Green

        static let secondary = Color(red: 0.9, green: 0.6, blue: 0.0) // Amber
        static let secondaryLight = Color(red: 1.0, green: 0.8, blue: 0.2) // Light Amber
        static let secondaryDark = Color(red: 0.7, green: 0.4, blue: 0.0) // Dark Amber

        static let accent = Color(red: 0.2, green: 0.6, blue: 0.9) // Professional Blue

        // MARK: - Functional Colors
        static let success = Color(red: 0.0, green: 0.7, blue: 0.3) // Success Green
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0) // Warning Orange
        static let error = Color(red: 0.9, green: 0.2, blue: 0.2) // Error Red
        static let info = Color(red: 0.2, green: 0.6, blue: 0.9) // Info Blue

        // Emergency and Alert Colors
        static let emergency = Color(red: 0.8, green: 0.0, blue: 0.0) // Emergency Red
        static let critical = Color(red: 1.0, green: 0.3, blue: 0.0) // Critical Orange

        // MARK: - Surface Colors
        static let background = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let backgroundTertiary = Color(.tertiarySystemBackground)

        static let surface = Color(.systemGray6)
        static let surfaceElevated = Color(.systemGray5)
        static let surfaceSecondary = Color(.systemGray4)

        // MARK: - Text Colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        static let textPlaceholder = Color(.placeholderText)

        // MARK: - Border Colors
        static let border = Color(.separator)
        static let borderSecondary = Color(.opaqueSeparator)

        // MARK: - Weather-specific Colors
        static let weatherSunny = Color(red: 1.0, green: 0.8, blue: 0.0)
        static let weatherCloudy = Color(red: 0.6, green: 0.6, blue: 0.7)
        static let weatherRainy = Color(red: 0.3, green: 0.5, blue: 0.8)
        static let weatherStormy = Color(red: 0.4, green: 0.4, blue: 0.5)

        // MARK: - Status Colors
        static let statusOnline = success
        static let statusOffline = Color(.systemGray)
        static let statusSyncing = accent
        static let statusPending = warning
        static let statusInProgress = info
        static let statusCompleted = success
    }

    // MARK: - Typography Scale

    /// Typography system optimized for pest control industry professionals
    struct Typography {

        // MARK: - Font Weights
        static let thin = Font.Weight.thin
        static let ultraLight = Font.Weight.ultraLight
        static let light = Font.Weight.light
        static let regular = Font.Weight.regular
        static let medium = Font.Weight.medium
        static let semibold = Font.Weight.semibold
        static let bold = Font.Weight.bold
        static let heavy = Font.Weight.heavy
        static let black = Font.Weight.black

        // MARK: - Display Typography
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .default)

        // MARK: - Headline Typography
        static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .default)
        static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)

        // MARK: - Title Typography
        static let titleLarge = Font.system(size: 20, weight: .regular, design: .default)
        static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)
        static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)

        // MARK: - Body Typography
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)

        // MARK: - Label Typography
        static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)

        // MARK: - Caption Typography
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionEmphasis = Font.system(size: 12, weight: .medium, design: .default)

        // MARK: - Monospace Typography (for technical data)
        static let monospaceBody = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let monospaceCaption = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing System

    /// Consistent spacing system based on 4pt grid
    struct Spacing {
        static let xxxs: CGFloat = 2   // 2pt
        static let xxs: CGFloat = 4    // 4pt
        static let xs: CGFloat = 8     // 8pt
        static let sm: CGFloat = 12    // 12pt
        static let md: CGFloat = 16    // 16pt
        static let lg: CGFloat = 20    // 20pt
        static let xl: CGFloat = 24    // 24pt
        static let xxl: CGFloat = 32   // 32pt
        static let xxxl: CGFloat = 40  // 40pt
        static let huge: CGFloat = 48  // 48pt

        // Semantic spacing
        static let cardPadding = md
        static let sectionSpacing = xl
        static let componentSpacing = sm
        static let elementSpacing = xs
    }

    // MARK: - Border Radius

    /// Consistent border radius system
    struct BorderRadius {
        static let none: CGFloat = 0
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999

        // Semantic radius
        static let card = md
        static let button = sm
        static let field = xs
        static let badge = full
    }

    // MARK: - Shadows

    /// Shadow system for elevation and depth
    struct Shadows {
        static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let sm = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let md = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let lg = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xl = Shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

        // Semantic shadows
        static let card = md
        static let modal = lg
        static let dropdown = sm
    }

    // MARK: - Component Styles

    /// Predefined component styling
    struct Components {

        // MARK: - Card Style
        struct Card {
            static let backgroundColor = Colors.surface
            static let cornerRadius = BorderRadius.card
            static let padding = Spacing.cardPadding
            static let shadow = Shadows.card
            static let borderColor = Colors.border
            static let borderWidth: CGFloat = 1
        }

        // MARK: - Button Styles
        struct Button {
            static let cornerRadius = BorderRadius.button
            static let padding = EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md)
            static let minHeight: CGFloat = 44 // Accessibility minimum

            // Primary button
            static let primaryBackgroundColor = Colors.primary
            static let primaryTextColor = Color.white
            static let primaryShadow = Shadows.sm

            // Secondary button
            static let secondaryBackgroundColor = Colors.surface
            static let secondaryTextColor = Colors.primary
            static let secondaryBorderColor = Colors.primary
            static let secondaryBorderWidth: CGFloat = 1

            // Emergency button
            static let emergencyBackgroundColor = Colors.emergency
            static let emergencyTextColor = Color.white
            static let emergencyPulseAnimation = true
        }

        // MARK: - Navigation Styles
        struct Navigation {
            // Top Navigation
            static let height: CGFloat = 56
            static let backgroundColor = Colors.background
            static let borderColor = Colors.border
            static let borderWidth: CGFloat = 1
            static let iconSize: CGFloat = 24
            static let badgeSize: CGFloat = 20

            // Bottom Navigation
            struct BottomTab {
                static let iconSize: CGFloat = 18
                static let fontSize: CGFloat = 11
                static let iconWeight: Font.Weight = .medium
                static let spacing: CGFloat = 2 // Between icon and text
                static let verticalPadding: CGFloat = 8
                static let horizontalPadding: CGFloat = 2
                static let containerVerticalPadding: CGFloat = 6
                static let containerHorizontalPadding = Spacing.md
            }
        }

        // MARK: - Status Indicator Styles
        struct StatusIndicator {
            static let size: CGFloat = 12
            static let borderWidth: CGFloat = 2
            static let borderColor = Color.white
            static let shadow = Shadows.sm
        }
    }
}

// MARK: - Color Extension for Fallback

extension Color {
    func fallback(_ fallbackColor: Color) -> Color {
        return self
    }
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Design System View Modifiers

extension View {
    /// Apply PestGenie card styling
    func pestGenieCard() -> some View {
        self
            .padding(PestGenieDesignSystem.Components.Card.padding)
            .background(PestGenieDesignSystem.Components.Card.backgroundColor)
            .cornerRadius(PestGenieDesignSystem.Components.Card.cornerRadius)
            .shadow(
                color: PestGenieDesignSystem.Shadows.card.color,
                radius: PestGenieDesignSystem.Shadows.card.radius,
                x: PestGenieDesignSystem.Shadows.card.x,
                y: PestGenieDesignSystem.Shadows.card.y
            )
    }

    /// Apply primary button styling
    func pestGeniePrimaryButton() -> some View {
        self
            .font(PestGenieDesignSystem.Typography.labelLarge)
            .foregroundColor(PestGenieDesignSystem.Components.Button.primaryTextColor)
            .frame(minHeight: PestGenieDesignSystem.Components.Button.minHeight)
            .padding(EdgeInsets(
                top: PestGenieDesignSystem.Components.Button.padding.top,
                leading: PestGenieDesignSystem.Components.Button.padding.leading,
                bottom: PestGenieDesignSystem.Components.Button.padding.bottom,
                trailing: PestGenieDesignSystem.Components.Button.padding.trailing
            ))
            .background(PestGenieDesignSystem.Components.Button.primaryBackgroundColor)
            .cornerRadius(PestGenieDesignSystem.Components.Button.cornerRadius)
            .shadow(
                color: PestGenieDesignSystem.Components.Button.primaryShadow.color,
                radius: PestGenieDesignSystem.Components.Button.primaryShadow.radius,
                x: PestGenieDesignSystem.Components.Button.primaryShadow.x,
                y: PestGenieDesignSystem.Components.Button.primaryShadow.y
            )
    }

    /// Apply secondary button styling
    func pestGenieSecondaryButton() -> some View {
        self
            .font(PestGenieDesignSystem.Typography.labelLarge)
            .foregroundColor(PestGenieDesignSystem.Components.Button.secondaryTextColor)
            .frame(minHeight: PestGenieDesignSystem.Components.Button.minHeight)
            .padding(EdgeInsets(
                top: PestGenieDesignSystem.Components.Button.padding.top,
                leading: PestGenieDesignSystem.Components.Button.padding.leading,
                bottom: PestGenieDesignSystem.Components.Button.padding.bottom,
                trailing: PestGenieDesignSystem.Components.Button.padding.trailing
            ))
            .background(PestGenieDesignSystem.Components.Button.secondaryBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.Components.Button.cornerRadius)
                    .stroke(PestGenieDesignSystem.Components.Button.secondaryBorderColor, lineWidth: PestGenieDesignSystem.Components.Button.secondaryBorderWidth)
            )
            .cornerRadius(PestGenieDesignSystem.Components.Button.cornerRadius)
    }

    /// Apply emergency button styling with pulse animation
    func pestGenieEmergencyButton() -> some View {
        self
            .font(PestGenieDesignSystem.Typography.labelLarge)
            .fontWeight(.bold)
            .foregroundColor(PestGenieDesignSystem.Components.Button.emergencyTextColor)
            .frame(minHeight: PestGenieDesignSystem.Components.Button.minHeight)
            .padding(EdgeInsets(
                top: PestGenieDesignSystem.Components.Button.padding.top,
                leading: PestGenieDesignSystem.Components.Button.padding.leading,
                bottom: PestGenieDesignSystem.Components.Button.padding.bottom,
                trailing: PestGenieDesignSystem.Components.Button.padding.trailing
            ))
            .background(PestGenieDesignSystem.Components.Button.emergencyBackgroundColor)
            .cornerRadius(PestGenieDesignSystem.Components.Button.cornerRadius)
            .shadow(
                color: PestGenieDesignSystem.Shadows.md.color,
                radius: PestGenieDesignSystem.Shadows.md.radius,
                x: PestGenieDesignSystem.Shadows.md.x,
                y: PestGenieDesignSystem.Shadows.md.y
            )
    }

    /// Apply status indicator styling
    func pestGenieStatusIndicator(color: Color) -> some View {
        self
            .frame(width: PestGenieDesignSystem.Components.StatusIndicator.size, height: PestGenieDesignSystem.Components.StatusIndicator.size)
            .background(color)
            .overlay(
                Circle()
                    .stroke(PestGenieDesignSystem.Components.StatusIndicator.borderColor, lineWidth: PestGenieDesignSystem.Components.StatusIndicator.borderWidth)
            )
            .clipShape(Circle())
            .shadow(
                color: PestGenieDesignSystem.Components.StatusIndicator.shadow.color,
                radius: PestGenieDesignSystem.Components.StatusIndicator.shadow.radius,
                x: PestGenieDesignSystem.Components.StatusIndicator.shadow.x,
                y: PestGenieDesignSystem.Components.StatusIndicator.shadow.y
            )
    }
}

// MARK: - Accessibility Helpers

extension PestGenieDesignSystem {
    /// Accessibility-focused design guidelines
    struct Accessibility {
        static let minimumTouchTarget: CGFloat = 44
        static let minimumTextSize: CGFloat = 12
        static let highContrastModeSupport = true
        static let reduceMotionSupport = true

        /// Check if current environment supports dynamic type
        static var supportsDynamicType: Bool {
            return true
        }

        /// Get accessible color pair with sufficient contrast
        static func accessibleColorPair(foreground: Color, background: Color) -> (foreground: Color, background: Color) {
            // In a real implementation, this would calculate contrast ratios
            // and return high-contrast alternatives if needed
            return (foreground: foreground, background: background)
        }
    }
}

// MARK: - Preview Support

#Preview("Design System Colors") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PestGenieDesignSystem.Spacing.md) {
            Group {
                colorSwatch("Primary", PestGenieDesignSystem.Colors.primary)
                colorSwatch("Secondary", PestGenieDesignSystem.Colors.secondary)
                colorSwatch("Success", PestGenieDesignSystem.Colors.success)
                colorSwatch("Warning", PestGenieDesignSystem.Colors.warning)
                colorSwatch("Error", PestGenieDesignSystem.Colors.error)
                colorSwatch("Emergency", PestGenieDesignSystem.Colors.emergency)
            }
        }
        .padding()
    }
}

#Preview("Design System Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Group {
                Text("Display Large").font(PestGenieDesignSystem.Typography.displayLarge)
                Text("Headline Large").font(PestGenieDesignSystem.Typography.headlineLarge)
                Text("Title Large").font(PestGenieDesignSystem.Typography.titleLarge)
                Text("Body Large").font(PestGenieDesignSystem.Typography.bodyLarge)
                Text("Label Large").font(PestGenieDesignSystem.Typography.labelLarge)
                Text("Caption").font(PestGenieDesignSystem.Typography.caption)
            }
        }
        .padding()
    }
}

private func colorSwatch(_ name: String, _ color: Color) -> some View {
    VStack {
        Rectangle()
            .fill(color)
            .frame(height: 60)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        Text(name)
            .font(PestGenieDesignSystem.Typography.caption)
            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
    }
}