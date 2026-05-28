import SwiftUI
import Combine

final class GameViewModel: ObservableObject {
@Published private(set) var snake: [Point] = []
@Published private(set) var food: Point = Point(x: 0, y: 0)
@Published private(set) var score: Int = 0
@Published private(set) var bestScore: Int = UserDefaults.standard.integer(forKey: "bestScore")
@Published private(set) var state: GameState = .idle

private var direction: Direction = .right
private var pendingDirection: Direction = .right
private var timer: AnyCancellable?

let columns = GameConfig.columns
let rows = GameConfig.rows

init() {
    reset()
}

func start() {
    if state == .gameOver || state == .idle {
        reset()
    }
    state = .playing
    startTimer()
}

func pause() {
    guard state == .playing else { return }
    state = .paused
    timer?.cancel()
    timer = nil
}

func resume() {
    guard state == .paused else { return }
    state = .playing
    startTimer()
}

func reset() {
    let startX = columns / 2
    let startY = rows / 2
    snake = [
        Point(x: startX, y: startY),
        Point(x: startX - 1, y: startY),
        Point(x: startX - 2, y: startY)
    ]
    direction = .right
    pendingDirection = .right
    score = 0
    state = .idle
    spawnFood()
    timer?.cancel()
    timer = nil
}

func change(direction newDirection: Direction) {
    guard newDirection != direction.opposite else { return }
    pendingDirection = newDirection
}

private func startTimer() {
    timer?.cancel()
    timer = Timer.publish(every: GameConfig.tickInterval, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in self?.tick() }
}

private func tick() {
    guard state == .playing else { return }
    direction = pendingDirection
    guard let head = snake.first else { return }
    let newHead = Point(x: head.x + direction.delta.x, y: head.y + direction.delta.y)

    // wall collision
    if newHead.x < 0 || newHead.x >= columns || newHead.y < 0 || newHead.y >= rows {
        gameOver(); return
    }
    // self collision
    if snake.contains(newHead) {
        gameOver(); return
    }

    var newSnake = [newHead] + snake
    if newHead == food {
        score += 1
        spawnFood()
    } else {
        newSnake.removeLast()
    }
    snake = newSnake
}

private func spawnFood() {
    let occupied = Set(snake)
    var candidate: Point
    repeat {
        candidate = Point(x: Int.random(in: 0..<columns), y: Int.random(in: 0..<rows))
    } while occupied.contains(candidate)
    food = candidate
}

private func gameOver() {
    state = .gameOver
    timer?.cancel()
    timer = nil
    if score > bestScore {
        bestScore = score
        UserDefaults.standard.set(score, forKey: "bestScore")
    }
}
}
