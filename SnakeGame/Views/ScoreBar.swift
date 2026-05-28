import SwiftUI

struct ScoreBar: View {
let score: Int
let best: Int
let state: GameState

var body: some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text("Счёт").font(.caption).foregroundColor(.secondary)
            Text("\(score)").font(.title2.bold())
        }
        Spacer()
        statusLabel
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
            Text("Рекорд").font(.caption).foregroundColor(.secondary)
            Text("\(best)").font(.title2.bold())
        }
    }
    .padding(12)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
}

private var statusLabel: some View {
    let text: String
    let color: Color
    switch state {
    case .idle:     text = "Готов";    color = .gray
    case .playing:  text = "Играем";  color = .green
    case .paused:   text = "Пауза";   color = .orange
    case .gameOver: text = "Конец";   color = .red
    }
    return Text(text)
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundColor(color)
}
}
