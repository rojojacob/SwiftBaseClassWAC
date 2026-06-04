//
//  PrimaryButton.swift
//  SwiftBaseClassWAC
//
//  Reusable primary call-to-action button built from design tokens.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.title)
                .frame(minWidth: 64, minHeight: 44)
                .padding(.horizontal, AppSpacing.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColor.accent)
    }
}

#Preview {
    PrimaryButton(title: "+") {}
}
