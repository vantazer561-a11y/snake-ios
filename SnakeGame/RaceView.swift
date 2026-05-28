import SwiftUI
import SceneKit
import CoreMotion

struct RaceView: View {
@StateObject private var game = RaceGame()

var body: some View {
    ZStack {
        RaceSceneView(game: game)
            .ignoresSafeArea()

        // HUD
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAP \(game.currentLap)/\(game.totalLaps)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                    Text(String(format: "TIME %.2f", game.elapsed))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                    if let best = game.bestLap {
                        Text(String(format: "BEST %.2f", best))
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.45))
                .cornerRadius(10)
                .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%3d", Int(game.speedKmh)))
                        .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    Text("km/h")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .padding(10)
                .background(Color.black.opacity(0.45))
                .cornerRadius(10)
                .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)

            Spacer()

            if game.finished {
                VStack(spacing: 10) {
                    Text("RACE COMPLETE")
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    if let best = game.bestLap {
                        Text(String(format: "Best lap: %.2fs", best))
                            .font(.system(size: 16, design: .monospaced))
                    }
                    Text(String(format: "Total: %.2fs", game.elapsed))
                        .font(.system(size: 16, design: .monospaced))
                    Button(action: { game.restart() }) {
                        Text("RESTART")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
                .cornerRadius(14)
                .foregroundColor(.white)
            }

            Spacer()

            // Touch controls
            HStack {
                // Brake (left)
                Button(action: {}) {
                    Text("BRAKE")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .frame(width: 120, height: 90)
                        .background(Color.red.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in game.brakingPressed = true }
                        .onEnded { _ in game.brakingPressed = false }
                )

                Spacer()

                // Steering pad
                HStack(spacing: 8) {
                    steerButton(label: "◀", isLeft: true)
                    steerButton(label: "▶", isLeft: false)
                }

                Spacer()

                // Throttle (right)
                Button(action: {}) {
                    Text("GAS")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .frame(width: 120, height: 90)
                        .background(Color.green.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in game.throttlePressed = true }
                        .onEnded { _ in game.throttlePressed = false }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 36)
        }
    }
    .background(Color.black)
}

private func steerButton(label: String, isLeft: Bool) -> some View {
    Button(action: {}) {
        Text(label)
            .font(.system(size: 28, weight: .heavy, design: .monospaced))
            .frame(width: 70, height: 90)
            .background(Color.white.opacity(0.18))
            .foregroundColor(.white)
            .cornerRadius(14)
    }
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if isLeft { game.steerLeftPressed = true }
                else { game.steerRightPressed = true }
            }
            .onEnded { _ in
                if isLeft { game.steerLeftPressed = false }
                else { game.steerRightPressed = false }
            }
    )
}
}
