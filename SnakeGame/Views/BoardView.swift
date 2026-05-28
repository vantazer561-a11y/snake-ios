import SwiftUI

struct BoardView: View {
@ObservedObject var vm: GameViewModel

var body: some View {
    GeometryReader { geo in
        let cellW = geo.size.width / CGFloat(vm.columns)
        let cellH = geo.size.height / CGFloat(vm.rows)
        let cell = min(cellW, cellH)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))

            // grid
            Path { path in
                for c in 0...vm.columns {
                    let x = CGFloat(c) * cell
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: CGFloat(vm.rows) * cell))
                }
                for r in 0...vm.rows {
                    let y = CGFloat(r) * cell
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: CGFloat(vm.columns) * cell, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)

            // food
            Circle()
                .fill(Color.red)
                .frame(width: cell * 0.85, height: cell * 0.85)
                .position(x: CGFloat(vm.food.x) * cell + cell / 2,
                          y: CGFloat(vm.food.y) * cell + cell / 2)

            // snake
            ForEach(Array(vm.snake.enumerated()), id: \.offset) { idx, segment in
                RoundedRectangle(cornerRadius: cell * 0.25)
                    .fill(idx == 0 ? Color.green : Color.green.opacity(0.75))
                    .frame(width: cell * 0.9, height: cell * 0.9)
                    .position(x: CGFloat(segment.x) * cell + cell / 2,
                              y: CGFloat(segment.y) * cell + cell / 2)
            }
        }
        .frame(width: CGFloat(vm.columns) * cell, height: CGFloat(vm.rows) * cell)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
}
