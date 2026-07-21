import SwiftUI

/// Animated "aurora" backdrop — soft brand-colored blobs that drift and shift hue
/// behind the (frosted) content. Subtle and slow so text/cards stay readable.
struct AppBackground: View {
    @State private var animate = false

    // Muted, low-saturation tones — kept subtle (no bright pink).
    private let blobs: [(color: Color, a: UnitPoint, b: UnitPoint)] = [
        (Color(red: 0.30, green: 0.29, blue: 0.52), UnitPoint(x: 0.15, y: 0.18), UnitPoint(x: 0.40, y: 0.42)), // indigo
        (Color(red: 0.42, green: 0.33, blue: 0.54), UnitPoint(x: 0.82, y: 0.16), UnitPoint(x: 0.58, y: 0.50)), // violet
        (Color(red: 0.24, green: 0.40, blue: 0.56), UnitPoint(x: 0.22, y: 0.82), UnitPoint(x: 0.50, y: 0.62)), // blue
        (Color(red: 0.22, green: 0.45, blue: 0.46), UnitPoint(x: 0.80, y: 0.82), UnitPoint(x: 0.42, y: 0.30)), // teal
        (Color(red: 0.48, green: 0.34, blue: 0.44), UnitPoint(x: 0.52, y: 0.10), UnitPoint(x: 0.30, y: 0.55)), // muted mauve
        (Color(red: 0.46, green: 0.42, blue: 0.34), UnitPoint(x: 0.10, y: 0.52), UnitPoint(x: 0.72, y: 0.22)), // soft sand
    ]

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            GeometryReader { geo in
                let d = max(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(blobs.indices, id: \.self) { i in
                        let p = animate ? blobs[i].b : blobs[i].a
                        Circle()
                            .fill(blobs[i].color)
                            .frame(width: d * 0.7, height: d * 0.7)
                            .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                    }
                }
                .blur(radius: 110)
                .hueRotation(.degrees(animate ? 14 : -10))
                .opacity(0.32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
