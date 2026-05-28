import Foundation

struct Point: Hashable {
var x: Int
var y: Int
}

enum Direction {
case up, down, left, right

var delta: Point {
    switch self {
    case .up:    return Point(x: 0, y: -1)
    case .down:  return Point(x: 0, y: 1)
    case .left:  return Point(x: -1, y: 0)
    case .right: return Point(x: 1, y: 0)
    }
}

var opposite: Direction {
    switch self {
    case .up: return .down
    case .down: return .up
    case .left: return .right
    case .right: return .left
    }
}
}

enum GameState {
case idle
case playing
case paused
case gameOver
}

struct GameConfig {
static let columns = 20
static let rows = 28
static let tickInterval: TimeInterval = 0.18
}
