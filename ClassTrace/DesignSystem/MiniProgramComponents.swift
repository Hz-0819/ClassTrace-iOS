import SwiftUI
import UIKit

enum MPColor {
    static let blue = Color(red: 123 / 255, green: 163 / 255, blue: 192 / 255)
    static let coral = Color(red: 232 / 255, green: 180 / 255, blue: 168 / 255)
    static let green = Color(red: 106 / 255, green: 160 / 255, blue: 138 / 255)
    static let gold = Color(red: 212 / 255, green: 165 / 255, blue: 116 / 255)
    static let red = Color(red: 220 / 255, green: 120 / 255, blue: 120 / 255)
    static let text = Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255)
    static let secondary = Color(red: 154 / 255, green: 168 / 255, blue: 176 / 255)
    static let page = Color(red: 247 / 255, green: 249 / 255, blue: 252 / 255)
}

struct MPLegacyImage: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let image = LegacyImageLoader.image(named: name) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo.badge.exclamationmark")
                    .resizable().scaledToFit().foregroundStyle(MPColor.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
private enum LegacyImageLoader {
    static func image(named name: String) -> UIImage? {
        if let image = UIImage(named: name) { return image }
        let directories = ["LegacyImages", "Resources/LegacyImages", nil]
        for directory in directories {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: directory),
               let image = UIImage(contentsOfFile: url.path) { return image }
        }
        if let root = Bundle.main.resourceURL,
           let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil),
           let url = enumerator.compactMap({ $0 as? URL }).first(where: { $0.lastPathComponent.caseInsensitiveCompare("\(name).png") == .orderedSame }) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}

struct MPPageHeader<Trailing: View>: View {
    let greeting: String
    let name: String
    let trailing: Trailing

    init(greeting: String, name: String, @ViewBuilder trailing: () -> Trailing) {
        self.greeting = greeting
        self.name = name
        self.trailing = trailing()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MPColor.blue
            Circle().fill(.white.opacity(0.10)).frame(width: 120, height: 120).offset(x: 145, y: -75)
            Circle().fill(.white.opacity(0.08)).frame(width: 72, height: 72).offset(x: -170, y: -15)
            Circle().fill(.white.opacity(0.07)).frame(width: 44, height: 44).offset(x: 125, y: 48)
            VStack(spacing: 26) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(.white.opacity(0.22)).frame(width: 38, height: 38)
                            MPLegacyImage(name: "icon", size: 28)
                        }
                        Text("课迹 ClassTrace").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    }
                    Spacer()
                    trailing
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting).font(.system(size: 15)).foregroundStyle(.white.opacity(0.78))
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        if DemoMode.isEnabled {
                            Text("演示模式").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.20), in: Capsule())
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
        }
        .frame(height: 190)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

struct MPSectionHeader: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2).fill(MPColor.blue).frame(width: 3, height: 18)
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(MPColor.text)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 3) { Text(action); Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)) }
                        .font(.system(size: 13)).foregroundStyle(MPColor.blue)
                }
            }
        }
    }
}

struct MPCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.055), radius: 10, y: 3)
    }
}

struct MPIconTile: View {
    let image: String
    let color: Color
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(color.opacity(0.15))
            MPLegacyImage(name: image, size: size * 0.55)
        }.frame(width: size, height: size)
    }
}

struct MPMenuRow<Destination: View>: View {
    let title: String
    let image: String
    let color: Color
    let destination: Destination

    init(title: String, image: String, color: Color, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.image = image
        self.color = color
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                MPIconTile(image: image, color: color, size: 42)
                Text(title).font(.system(size: 15)).foregroundStyle(MPColor.text)
                Spacer()
                MPLegacyImage(name: "right", size: 14).opacity(0.45)
            }.padding(.vertical, 5)
        }.buttonStyle(.plain)
    }
}

struct MPEmptyView: View {
    let image: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 10) {
            MPLegacyImage(name: image, size: 54).opacity(0.65)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
            Text(detail).font(.system(size: 13)).foregroundStyle(MPColor.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}
