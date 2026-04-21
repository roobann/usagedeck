import AppKit
import SwiftUI

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            CircleGaugeGlyph()
                .frame(width: 140, height: 140)
                .foregroundStyle(.primary)

            VStack(spacing: 4) {
                Text("Usage Deck")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("AI Usage Monitor")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track usage across multiple AI providers")
                FeatureRow(icon: "bell.badge", text: "Smart notifications at custom thresholds")
                FeatureRow(icon: "rectangle.stack", text: "Multi-account support")
                FeatureRow(icon: "clock.arrow.circlepath", text: "Automatic refresh")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: self.icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(self.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension AboutPane {
    static func loadAppLogo() -> NSImage? {
        if let url = Bundle.moduleResources.url(forResource: "logo-usagedeck", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "logo-usagedeck", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

/// Lucide `circle-gauge`, drawn natively so it tints with `foregroundStyle`
/// and stays crisp at any size.
struct CircleGaugeGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 24
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let lineWidth = 2 * scale

            ZStack {
                // Open arc: most of a circle with a gap at upper-right.
                Path { p in
                    p.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: 10 * scale,
                        startAngle: .degrees(-68.84),
                        endAngle: .degrees(-21.16),
                        clockwise: true
                    )
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // Center hub.
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth))
                    .frame(width: 4 * scale, height: 4 * scale)
                    .position(x: cx, y: cy)

                // Needle from (13.4, 10.6) to (19, 5), mirrored from SVG Y-down.
                Path { p in
                    p.move(to: CGPoint(x: cx + 1.4 * scale, y: cy - 1.4 * scale))
                    p.addLine(to: CGPoint(x: cx + 7 * scale, y: cy - 7 * scale))
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}
