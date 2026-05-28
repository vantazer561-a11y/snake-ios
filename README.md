# SnakeGame (iOS 15+)

Классическая змейка на SwiftUI. Минимальная цель iOS 15.

## Управление
- Свайпы по полю
- Стрелки внизу экрана
- Start / Pause / Reset

## Архитектура
MVVM: `GameViewModel` хранит состояние, `Views/*` рендерят.

## Сборка
1. Xcode → File → New → Project → App (SwiftUI, Swift, iOS 15.0).
2. Создай проект `SnakeGame`, замени дефолтные файлы файлами из папки `SnakeGame/`.
3. Cmd+R на симуляторе iPhone.
