import SwiftUI

// MARK: - ShareCardView (#49 — shareable week card)
/// A self-contained visual rendered to an image and shared. Takes plain values
/// (no environment) so `ImageRenderer` can rasterize it off-screen.
struct ShareCardView: View {
    let weekRange: String
    let moodEmoji: String
    let moodLabel: String
    let streak: Int
    let checkIns: Int
    let themes: [String]
    let primary: Color
    let secondary: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primary)
                Text("Serenity")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(weekRange)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Text(moodEmoji).font(.system(size: 72))
            Text(moodLabel)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(L("share.week_mood"))
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            HStack(spacing: 12) {
                statPill(value: "\(streak)", label: L("report.streak"))
                statPill(value: "\(checkIns)", label: L("report.check_ins"))
            }

            if !themes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
                .padding(.top, 12)
            }

            Spacer()

            Text(L("share.tagline"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(28)
        .frame(width: 320, height: 420)
        .background(
            ZStack {
                Color(hex: "0B1020")
                RadialGradient(
                    colors: [primary.opacity(0.45), secondary.opacity(0.15), .clear],
                    center: .top, startRadius: 0, endRadius: 360)
            }
        )
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(minWidth: 90)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

// MARK: - Share sheet
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
