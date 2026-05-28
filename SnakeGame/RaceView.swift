import SwiftUI

struct RaceView: View {
@StateObject private var game = RaceGame()
@Environment(\.dismiss) private var dismiss

var body: some View {
    ZStack {
        // 3D scene
        RaceSceneView(game: game)
            .ignoresSafeArea()
            .onAppear { game.start() }

        // HUD overlay
        VStack {
            // Top bar: lap / timer / best lap / back
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }

                Spacer()

                HStack(spacing: 16) {
                    HUDStat(label: "LAP",
                            value: "\(game.currentLap)/\(game.totalLaps)")
                    HUDStat(label: "TIME",
                            value: format(game.elapsed))
                    HUDStat(label: "BEST",
                            value: game.bestLap.map(format) ?? "--:--")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Bottom controls row
            HStack(spacing: 0) {
                // BRAKE (left)
                ControlPad(label: "BRAKE", color: .red,
                           pressed: Binding(get: { game.brakingPressed },
                                            set: { game.brakingPressed = $0 }))

                Spacer(minLength: 0)

                // Steering
                VStack(spacing: 10) {
                    HStack(spacing: 18) {
                        ArrowButton(symbol: "arrow.left",
                                    pressed: Binding(get: { game.steerLeftPressed },
                                                     set: { game.steerLeftPressed = $0 }))
                        ArrowButton(symbol: "arrow.right",
                                    pressed: Binding(get: { game.steerRightPressed },
                                                     set: { game.steerRightPressed = $0 }))
                    }
                    TurboButton(active: game.turboActive,
                                available: game.turboAvailable,
                                pressed: Binding(get: { game.turboPressed },
                                                 set: { game.turboPressed = $0 }))
                }

                Spacer(minLength: 0)

                // GAS (right)
                ControlPad(label: "GAS", color: .green,
                           pressed: Binding(get: { game.throttlePressed },
                                            set: { game.throttlePressed = $0 }))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)

            // Speed bar
            HStack {
                Spacer()
                SpeedReadout(kmh: game.speedKmh)
                    .padding(.bottom, 6)
                Spacer()
            }
        }

        // Finished overlay
        if game.finished {
            FinishedOverlay(game: game) {
                game.restart()
            } onMenu: {
                dismiss()
            }
        }
    }
    .background(Color.black)
    .statusBarHidden(true)
}

private func format(_ t: Double) -> String {
    let m = Int(t) / 60
    let s = t - Double(m * 60)
    return String(format: "%d:%05.2f", m, s)
}
}

// MARK: - HUD parts

private struct HUDStat: View {
let label: String
let value: String
var body: some View {
    VStack(spacing: 2) {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(2)
            .foregroundColor(.white.opacity(0.65))
        Text(value)
            .font(.system(size: 16, weight: .heavy, design: .monospaced))
            .foregroundColor(.white)
    }
}
}

private struct SpeedReadout: View {
let kmh: Double
var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 4) {
        Text("\(Int(kmh))")
            .font(.system(size: 38, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
        Text("km/h")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.7))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.35))
    .clipShape(Capsule())
}
}

private struct ControlPad: View {
let label: String
let color: Color
@Binding var pressed: Bool

var body: some View {
    ZStack {
        Circle()
            .fill(color.opacity(pressed ? 0.85 : 0.55))
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
            .shadow(color: color.opacity(0.6), radius: pressed ? 14 : 6)
        Text(label)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
    }
    .frame(width: 95, height: 95)
    .gesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
    )
}
}

private struct ArrowButton: View {
let symbol: String
@Binding var pressed: Bool

var body: some View {
    Image(systemName: symbol)
        .font(.system(size: 22, weight: .heavy))
        .foregroundColor(.white)
        .frame(width: 64, height: 64)
        .background(Color.white.opacity(pressed ? 0.35 : 0.18))
        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
        .clipShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
}
}

private struct TurboButton: View {
let active: Bool
let available: Double // 0..1
@Binding var pressed: Bool

var body: some View {
    ZStack {
        Capsule()
            .fill(active
                  ? Color.orange.opacity(0.9)
                  : Color.purple.opacity(available > 0.05 ? 0.65 : 0.25))
            .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
            .shadow(color: (active ? Color.orange : Color.purple).opacity(0.6),
                    radius: active ? 18 : 6)

        // fuel bar
        GeometryReader { geo in
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: geo.size.width * CGFloat(max(0, min(1, available))))
        }
        .clipShape(Capsule())
        .padding(3)

        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .heavy))
            Text("TURBO")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(2)
        }
        .foregroundColor(.white)
    }
    .frame(width: 146, height: 38)
    .gesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
    )
}
}

private struct FinishedOverlay: View {
@ObservedObject var game: RaceGame
var onRestart: () -> Void
var onMenu: () -> Void

var body: some View {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        VStack(spacing: 18) {
            Text("FINISH")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("Best lap: " + (game.bestLap.map(format) ?? "--:--"))
                .font(.title3.bold())
                .foregroundColor(.white.opacity(0.85))
            Text("Total time: " + format(game.elapsed))
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                Button {
                    onMenu()
                } label: {
                    Text("MENU")
                        .font(.headline.bold())
                        .frame(width: 110, height: 46)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    onRestart()
                } label: {
                    Text("RESTART")
                        .font(.headline.bold())
                        .frame(width: 140, height: 46)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private func format(_ t: Double) -> String {
    let m = Int(t) / 60
    let s = t - Double(m * 60)
    return String(format: "%d:%05.2f", m, s)
}
}
