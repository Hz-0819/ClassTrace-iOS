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
enum LegacyImageLoader {
    private static var decodedImages: [String: UIImage] = [:]
    private static let bundledPNGs: [String: URL] = {
        guard let root = Bundle.main.resourceURL,
              let enumerator = FileManager.default.enumerator(
                  at: root,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              )
        else { return [:] }

        var index: [String: URL] = [:]
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "png" {
            index[url.deletingPathExtension().lastPathComponent.lowercased()] = url
        }
        return index
    }()

    static func image(named name: String) -> UIImage? {
        let key = name.lowercased()
        if let cached = decodedImages[key] { return cached }
        if let image = UIImage(named: name) {
            decodedImages[key] = image
            return image
        }
        let directories = ["LegacyImages", "Resources/LegacyImages", nil]
        for directory in directories {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: directory),
               let image = UIImage(contentsOfFile: url.path) {
                decodedImages[key] = image
                return image
            }
        }
        if let url = bundledPNGs[key], let image = UIImage(contentsOfFile: url.path) {
            decodedImages[key] = image
            return image
        }
        return nil
    }
}

extension View {
    func mpFormChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(MPColor.page)
            .tint(MPColor.blue)
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
            LinearGradient(
                colors: [
                    MPColor.blue,
                    Color(red: 138 / 255, green: 176 / 255, blue: 201 / 255),
                    Color(red: 155 / 255, green: 184 / 255, blue: 204 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.08)).frame(width: 160, height: 160).offset(x: 150, y: -40)
            Circle().stroke(.white.opacity(0.15), lineWidth: 1).frame(width: 80, height: 80).offset(x: 85, y: -20)
            Circle().stroke(.white.opacity(0.10), lineWidth: 1).frame(width: 50, height: 50).offset(x: -205, y: 38)
            Circle().fill(.white.opacity(0.30)).frame(width: 5, height: 5).offset(x: -135, y: -32)
            Circle().fill(.white.opacity(0.25)).frame(width: 3, height: 3).offset(x: 150, y: 24)
            VStack(spacing: 20) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.95)).frame(width: 28, height: 28)
                            MPLegacyImage(name: "icon", size: 18)
                        }
                        Text("课迹 ClassTrace").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                    Spacer()
                    trailing
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting).font(.system(size: 12)).foregroundStyle(.white.opacity(0.80))
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        if DemoMode.isEnabled {
                            Text("演示模式").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(.white.opacity(0.20), in: Capsule())
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 34)

            if let image = LegacyImageLoader.image(named: "wave") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 160)
        .clipped()
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
