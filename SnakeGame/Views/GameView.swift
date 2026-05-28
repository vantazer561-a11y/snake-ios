import SwiftUI

struct GameView: View {
@ObservedObject var vm: GameViewModel

var body: some View {
    VStack(spacing: 16) {
        ScoreBar(score: vm.score, best: vm.bestScore, state: vm.state)
            .padding(.horizontal)

        BoardView(vm: vm)
            .aspectRatio(CGFloat(vm.columns) / CGFloat(vm.rows), contentMode: .fit)
            .padding(.horizontal)
            .gesture(swipeGesture)
            .overlay(overlayView)

        ControlsView(vm: vm)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
    .background(Color(.systemBackground).ignoresSafeArea())
}

@ViewBuilder
private var overlayView: some View {
    switch vm.state {
    case .idle:
        BannerView(title: "Snake", subtitle: "Нажми Start или свайпни")
    case .paused:
        BannerView(title: "Пауза", subtitle: "Нажми Resume")
    case .gameOver:
        BannerView(title: "Game Over", subtitle: "Счёт: \(vm.score)")
    case .playing:
        EmptyView()
    }
}

private var swipeGesture: some Gesture {
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            let dx = value.translation.width
            let dy = value.translation.height
            if abs(dx) > abs(dy) {
                vm.change(direction: dx > 0 ? .right : .left)
            } else {
                vm.change(direction: dy > 0 ? .down : .up)
            }
            if vm.state == .idle || vm.state == .gameOver {
                vm.start()
            }
        }
}
}

struct BannerView: View {
let title: String
let subtitle: String
var body: some View {
    VStack(spacing: 6) {
        Text(title).font(.system(size: 36, weight: .bold))
        Text(subtitle).font(.subheadline).foregroundColor(.secondary)
    }
    .padding(24)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
}
