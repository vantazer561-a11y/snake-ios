import SwiftUI

struct ContentView: View {
@StateObject private var vm = GameViewModel()

var body: some View {
    GameView(vm: vm)
}
}

#Preview {
ContentView()
}
