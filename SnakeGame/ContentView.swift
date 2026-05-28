import SwiftUI

struct ContentView: View {
@State private var showRace = false

var body: some View {
    ZStack {
        // Gradient background
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.05, blue: 0.12),
                Color(red: 0.35, green: 0.04, blue: 0.08)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        // Decorative checkered band
        VStack {
            Spacer()
            CheckerBand()
                .frame(height: 26)
                .opacity(0.5)
            Spacer().frame(height: 0)
        }

        VStack(spacing: 28) {
            Spacer()

            Text("F1")
                .font(.system(size: 110, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(red: 1, green: 0.7, blue: 0.7)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .red.opacity(0.6), radius: 18)

            Text("RACING")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(8)
                .foregroundColor(.white.opacity(0.85))

            Spacer()

            VStack(spacing: 14) {
                MenuButton(title: "RACE", systemImage: "flag.checkered") {
                    showRace = true
                }
                MenuButton(title: "CONTROLS", systemImage: "gamecontroller.fill") {
                    // simple alert via overlay would be nice — keep static
                }
                .opacity(0.55)
                .disabled(true)
            }
            .padding(.horizontal, 40)

            Spacer()

            Text("Tap RACE to start • 3 laps")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 30)
        }
    }
    .fullScreenCover(isPresented: $showRace) {
        RaceView()
    }
    .statusBarHidden(true)
}
}

private struct MenuButton: View {
let title: String
let systemImage: String
let action: () -> Void

var body: some View {
    Button(action: action) {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .tracking(2)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.75, green: 0.08, blue: 0.12),
                         Color(red: 0.5, green: 0.04, blue: 0.08)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .red.opacity(0.4), radius: 10, y: 4)
    }
}
}

private struct CheckerBand: View {
var body: some View {
    GeometryReader { geo in
        let cell: CGFloat = 26
        let cols = Int(ceil(geo.size.width / cell))
        HStack(spacing: 0) {
            ForEach(0..<cols, id: \.self) { i in
                Rectangle()
                    .fill(i % 2 == 0 ? Color.white : Color.black)
                    .frame(width: cell, height: cell)
            }
        }
    }
}
}
