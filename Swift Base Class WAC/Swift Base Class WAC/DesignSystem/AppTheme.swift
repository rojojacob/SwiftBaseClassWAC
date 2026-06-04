//
//  AppTheme.swift
//  Swift Base Class WAC
//
//  Centralized design tokens: spacing, colors, and typography.
//  Reference these everywhere instead of hard-coded literals so the
//  visual language stays consistent and is changeable in one place.
//

import SwiftUI

enum AppSpacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 40
}

enum AppColor {
    static let accent = Color.accentColor
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let surface = Color(.secondarySystemBackground)
}

enum AppFont {
    static let display = Font.system(size: 64, weight: .bold, design: .rounded)
    static let title = Font.title2.weight(.semibold)
    static let body = Font.body
}
