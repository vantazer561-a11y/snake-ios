import SwiftUI
import SceneKit

struct RaceSceneView: UIViewRepresentable {
let game: RaceGame

func makeUIView(context: Context) -> SCNView {
    let view = SCNView(frame: .zero)
    view.scene = game.scene
    view.allowsCameraControl = false
    view.showsStatistics = false
    view.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1.0)
    view.antialiasingMode = .multisampling2X
    view.preferredFramesPerSecond = 60
    view.isPlaying = true
    view.rendersContinuously = true
    view.pointOfView = game.cameraNode
    game.sceneView = view
    game.start()
    return view
}

func updateUIView(_ uiView: SCNView, context: Context) {
    // game drives the scene via its own render loop
}
}
