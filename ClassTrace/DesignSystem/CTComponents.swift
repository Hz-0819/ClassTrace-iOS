import SwiftUI

struct CTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.ctBrand.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.medium, style: .continuous))
    }
}

struct CTPrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CTSpacing.xs) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(isDisabled ? Color.ctBrand.opacity(0.45) : Color.ctBrand)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.medium, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .accessibilityAddTraits(.isButton)
    }
}

struct CTCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CTSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ctCard)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CTRadius.large, style: .continuous)
                    .stroke(Color.ctDivider.opacity(0.7), lineWidth: 0.5)
            }
    }
}

struct CTStateView: View {
    enum Kind {
        case empty, error, offline

        var symbol: String {
            switch self {
            case .empty: "tray"
            case .error: "exclamationmark.triangle"
            case .offline: "wifi.slash"
            }
        }
    }

    let kind: Kind
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: kind.symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.ctBrand)
            }
        }
    }
}

struct CTStatusBadge: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, CTSpacing.sm)
            .padding(.vertical, CTSpacing.xs)
            .background(color.opacity(0.12), in: Capsule())
    }
}
