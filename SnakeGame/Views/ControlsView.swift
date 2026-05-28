import SwiftUI

struct ControlsView: View {
@ObservedObject var vm: GameViewModel

var body: some View {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            actionButton
            Button {
                vm.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }

        HStack(spacing: 12) {
            Spacer()
            arrowButton(.up, "arrow.up")
            Spacer()
        }
        HStack(spacing: 12) {
            arrowButton(.left, "arrow.left")
            arrowButton(.down, "arrow.down")
            arrowButton(.right, "arrow.right")
        }
    }
}

@ViewBuilder
private var actionButton: some View {
    switch vm.state {
    case .idle, .gameOver:
        Button {
            vm.start()
        } label: {
            Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    case .playing:
        Button {
            vm.pause()
        } label: {
            Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    case .paused:
        Button {
            vm.resume()
        } label: {
            Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

private func arrowButton(_ dir: Direction, _ icon: String) -> some View {
    Button {
        vm.change(direction: dir)
        if vm.state == .idle || vm.state == .gameOver { vm.start() }
    } label: {
        Image(systemName: icon)
            .font(.title2.bold())
            .frame(width: 64, height: 48)
    }
    .buttonStyle(.bordered)
}
}
