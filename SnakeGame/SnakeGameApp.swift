import SwiftUI

@main
struct SnakeGameApp: App {
var body: some Scene {
    WindowGroup {
        RaceView()
            .ignoresSafeArea()
            .statusBarHidden(true)
            .preferredColorScheme(.dark)
    }
}
}
