import SwiftUI

/// Full-bleed square icon (squircle gradient + code glyph) used for the Dock icon.
struct SwiftexIconMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 224, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.27, blue: 1.0),
                                 Color(red: 0.55, green: 0.20, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 470, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// Swiftex brand mark — a gradient code badge + wordmark, shown atop the sidebar.
struct SwiftexLogo: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.27, blue: 1.0),
                                 Color(red: 0.55, green: 0.20, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.15))
                )
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text("Swiftex")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("iOS codegen")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
