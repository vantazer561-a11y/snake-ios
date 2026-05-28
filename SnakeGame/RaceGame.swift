import Foundation
import SceneKit
import SwiftUI
import Combine

final class RaceGame: NSObject, ObservableObject, SCNSceneRendererDelegate {

// MARK: - Published HUD state
@Published var speedKmh: Double = 0
@Published var currentLap: Int = 1
@Published var totalLaps: Int = 3
@Published var elapsed: Double = 0
@Published var bestLap: Double?
@Published var finished: Bool = false
@Published var turboAvailable: Double = 1.0   // 0..1, displayed as fuel bar
@Published var turboActive: Bool = false

// MARK: - Input flags (set by RaceView)
var throttlePressed: Bool = false
var brakingPressed: Bool = false
var steerLeftPressed: Bool = false
var steerRightPressed: Bool = false
var turboPressed: Bool = false

// MARK: - Scene
let scene: SCNScene
let cameraNode: SCNNode
weak var sceneView: SCNView?

// MARK: - Track
private let trackPoints: [SIMD2<Float>]
private let trackWidth: Float = 14.0

// MARK: - Car (player)
private let carNode: SCNNode
private var position: SIMD2<Float>
private var heading: Float
private var speed: Float = 0
private let baseMaxSpeed: Float = 75
private let turboMaxSpeed: Float = 110
private let maxSpeedRev: Float = 12
private var turboFuel: Float = 1.0   // 0..1

// MARK: - Opponents
private struct Opponent {
    let node: SCNNode
    var trackOffset: Float   // 0..1 along track
    var lateral: Float       // -trackWidth/2 .. +trackWidth/2
    var speed: Float
    let targetSpeed: Float
}
private var opponents: [Opponent] = []

// MARK: - Lap tracking
private var lapStartTime: TimeInterval = 0
private var raceStartTime: TimeInterval = 0
private var lastTime: TimeInterval = 0
private var hasCrossedHalfway: Bool = false
private let startLine: SIMD2<Float>
private let halfwayPoint: SIMD2<Float>
private var trackLength: Float = 0

override init() {
    self.scene = SCNScene()

    var pts: [SIMD2<Float>] = []
    let segments = 96
    let A: Float = 90
    let B: Float = 55
    for i in 0..<segments {
        let t = Float(i) / Float(segments) * .pi * 2
        var x = A * cos(t)
        var z = B * sin(t)
        let bump = sin(t * 3.0) * 6.0
        x += bump * 0.2
        z += cos(t * 4.0) * 3.0
        pts.append(SIMD2<Float>(x, z))
    }
    self.trackPoints = pts
    self.startLine = pts[0]
    self.halfwayPoint = pts[segments / 2]

    // Player car (burgundy/white)
    self.carNode = RaceGame.buildCar(bodyColor: UIColor(red: 0.55, green: 0.06, blue: 0.10, alpha: 1),
                                     accentWhite: true)
    self.position = pts[0]
    let next = pts[1]
    let dx = next.x - pts[0].x
    let dz = next.y - pts[0].y
    self.heading = atan2(dz, dx)

    // Camera: wider FOV
    let cam = SCNCamera()
    cam.zFar = 1200
    cam.zNear = 0.3
    cam.fieldOfView = 85   // wider than before
    cam.wantsHDR = true
    cam.bloomIntensity = 0.4
    cam.bloomThreshold = 0.85
    cam.bloomBlurRadius = 8
    cam.motionBlurIntensity = 0.25
    let camNode = SCNNode()
    camNode.camera = cam
    self.cameraNode = camNode

    super.init()

    // compute track length
    var L: Float = 0
    for i in 0..<trackPoints.count {
        let a = trackPoints[i]
        let b = trackPoints[(i + 1) % trackPoints.count]
        L += simd_distance(a, b)
    }
    self.trackLength = L

    buildEnvironment()
    buildTrack()
    spawnOpponents()

    carNode.position = SCNVector3(position.x, 0.4, position.y)
    carNode.eulerAngles = SCNVector3(0, -heading + .pi / 2, 0)
    scene.rootNode.addChildNode(carNode)
    scene.rootNode.addChildNode(camNode)
}

// MARK: - Lifecycle
func start() {
    sceneView?.delegate = self
    lastTime = 0
    raceStartTime = 0
    lapStartTime = 0
}

func restart() {
    speed = 0
    position = trackPoints[0]
    let next = trackPoints[1]
    heading = atan2(next.y - position.y, next.x - position.x)
    currentLap = 1
    elapsed = 0
    bestLap = nil
    finished = false
    hasCrossedHalfway = false
    lastTime = 0
    raceStartTime = 0
    lapStartTime = 0
    turboFuel = 1.0
    turboActive = false
    turboAvailable = 1.0
    // reset opponents
    for i in opponents.indices {
        opponents[i].trackOffset = Float.random(in: 0.02 ... 0.18)
        opponents[i].speed = 0
    }
}

// MARK: - Environment
private func buildEnvironment() {
    // Sky gradient (cube-like via background color and fog)
    let skyTop = UIColor(red: 0.45, green: 0.62, blue: 0.95, alpha: 1)
    let skyBot = UIColor(red: 0.85, green: 0.88, blue: 0.96, alpha: 1)
    let skyImg = RaceGame.gradientImage(size: CGSize(width: 4, height: 256),
                                        top: skyTop, bottom: skyBot)
    scene.background.contents = skyImg
    scene.lightingEnvironment.contents = skyImg
    scene.lightingEnvironment.intensity = 1.4

    // Sun
    let sun = SCNLight()
    sun.type = .directional
    sun.intensity = 1400
    sun.castsShadow = true
    sun.shadowMode = .deferred
    sun.shadowRadius = 8
    sun.shadowSampleCount = 16
    sun.shadowColor = UIColor(white: 0, alpha: 0.55)
    sun.orthographicScale = 90
    let sunNode = SCNNode()
    sunNode.light = sun
    sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
    scene.rootNode.addChildNode(sunNode)

    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.intensity = 280
    ambient.color = UIColor(white: 0.9, alpha: 1)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    // Ground (PBR grass)
    let ground = SCNFloor()
    ground.reflectivity = 0.04
    let groundMat = SCNMaterial()
    groundMat.lightingModel = .physicallyBased
    groundMat.diffuse.contents = UIColor(red: 0.22, green: 0.5, blue: 0.2, alpha: 1)
    groundMat.roughness.contents = 0.95
    groundMat.metalness.contents = 0
    ground.materials = [groundMat]
    let groundNode = SCNNode(geometry: ground)
    scene.rootNode.addChildNode(groundNode)

    // Fog: lighter, further
    scene.fogColor = UIColor(red: 0.78, green: 0.86, blue: 0.96, alpha: 1)
    scene.fogStartDistance = 320
    scene.fogEndDistance = 900

    // Trees ring (cones) for ambience
    let trunkMat = SCNMaterial()
    trunkMat.diffuse.contents = UIColor(red: 0.36, green: 0.22, blue: 0.12, alpha: 1)
    let leavesMat = SCNMaterial()
    leavesMat.lightingModel = .physicallyBased
    leavesMat.diffuse.contents = UIColor(red: 0.12, green: 0.4, blue: 0.18, alpha: 1)
    leavesMat.roughness.contents = 0.9

    let outerR: Float = 160
    for i in 0..<60 {
        let ang = Float(i) / 60 * .pi * 2
        let r = outerR + Float.random(in: -10...20)
        let x = cos(ang) * r
        let z = sin(ang) * r
        let trunk = SCNCylinder(radius: 0.3, height: 2.5)
        trunk.materials = [trunkMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(x, 1.25, z)
        scene.rootNode.addChildNode(trunkNode)
        let leaves = SCNCone(topRadius: 0, bottomRadius: 2.2, height: 5)
        leaves.materials = [leavesMat]
        let leavesNode = SCNNode(geometry: leaves)
        leavesNode.position = SCNVector3(x, 5, z)
        scene.rootNode.addChildNode(leavesNode)
    }
}

private static func gradientImage(size: CGSize, top: UIColor, bottom: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let cg = ctx.cgContext
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
        cg.drawLinearGradient(grad,
                              start: .zero,
                              end: CGPoint(x: 0, y: size.height),
                              options: [])
    }
}

// MARK: - Track
private func buildTrack() {
    let asphaltMat = SCNMaterial()
    asphaltMat.lightingModel = .physicallyBased
    asphaltMat.diffuse.contents = UIColor(white: 0.16, alpha: 1)
    asphaltMat.roughness.contents = 0.75
    asphaltMat.metalness.contents = 0

    let whiteMat = SCNMaterial()
    whiteMat.diffuse.contents = UIColor.white
    whiteMat.lightingModel = .physicallyBased
    whiteMat.roughness.contents = 0.5

    let redMat = SCNMaterial()
    redMat.diffuse.contents = UIColor.red
    redMat.lightingModel = .physicallyBased
    redMat.roughness.contents = 0.5

    for i in 0..<trackPoints.count {
        let a = trackPoints[i]
        let b = trackPoints[(i + 1) % trackPoints.count]
        let segLen = simd_distance(a, b)
        let seg = SCNBox(width: CGFloat(trackWidth), height: 0.05, length: CGFloat(segLen) + 0.2, chamferRadius: 0)
        seg.materials = [asphaltMat]
        let segNode = SCNNode(geometry: seg)
        let midX = (a.x + b.x) / 2
        let midZ = (a.y + b.y) / 2
        segNode.position = SCNVector3(midX, 0.025, midZ)
        let ang = atan2(b.y - a.y, b.x - a.x)
        segNode.eulerAngles = SCNVector3(0, -ang + .pi / 2, 0)
        scene.rootNode.addChildNode(segNode)

        let kerbColor = (i % 2 == 0) ? redMat : whiteMat
        let leftKerb = SCNBox(width: 1.2, height: 0.12, length: CGFloat(segLen) + 0.2, chamferRadius: 0)
        leftKerb.materials = [kerbColor]
        let lk = SCNNode(geometry: leftKerb)
        lk.position = SCNVector3(midX + cos(ang + .pi / 2) * (trackWidth / 2 + 0.6),
                                 0.06,
                                 midZ + sin(ang + .pi / 2) * (trackWidth / 2 + 0.6))
        lk.eulerAngles = SCNVector3(0, -ang + .pi / 2, 0)
        scene.rootNode.addChildNode(lk)

        let rk = SCNNode(geometry: leftKerb.copy() as! SCNGeometry)
        rk.position = SCNVector3(midX - cos(ang + .pi / 2) * (trackWidth / 2 + 0.6),
                                 0.06,
                                 midZ - sin(ang + .pi / 2) * (trackWidth / 2 + 0.6))
        rk.eulerAngles = SCNVector3(0, -ang + .pi / 2, 0)
        scene.rootNode.addChildNode(rk)
    }

    // Start/finish line
    let line = SCNBox(width: CGFloat(trackWidth), height: 0.06, length: 1.2, chamferRadius: 0)
    let lineMat = SCNMaterial()
    lineMat.diffuse.contents = UIColor.white
    line.materials = [lineMat]
    let lineNode = SCNNode(geometry: line)
    lineNode.position = SCNVector3(startLine.x, 0.06, startLine.y)
    let nxt = trackPoints[1]
    let ang = atan2(nxt.y - startLine.y, nxt.x - startLine.x)
    lineNode.eulerAngles = SCNVector3(0, -ang + .pi / 2, 0)
    scene.rootNode.addChildNode(lineNode)

    // Grandstands + flags
    let standMat = SCNMaterial()
    standMat.lightingModel = .physicallyBased
    standMat.diffuse.contents = UIColor(white: 0.75, alpha: 1)
    standMat.roughness.contents = 0.7
    for i in stride(from: 0, to: trackPoints.count, by: 16) {
        let p = trackPoints[i]
        let stand = SCNBox(width: 14, height: 4, length: 3, chamferRadius: 0.2)
        stand.materials = [standMat]
        let sn = SCNNode(geometry: stand)
        let dirAng = atan2(trackPoints[(i + 1) % trackPoints.count].y - p.y,
                           trackPoints[(i + 1) % trackPoints.count].x - p.x)
        let off: Float = trackWidth / 2 + 8
        sn.position = SCNVector3(p.x + cos(dirAng + .pi / 2) * off,
                                 2,
                                 p.y + sin(dirAng + .pi / 2) * off)
        sn.eulerAngles = SCNVector3(0, -dirAng + .pi / 2, 0)
        scene.rootNode.addChildNode(sn)
    }
}

// MARK: - Opponents
private func spawnOpponents() {
    let palette: [UIColor] = [
        UIColor(red: 0.05, green: 0.25, blue: 0.85, alpha: 1),   // blue
        UIColor(red: 0.0, green: 0.55, blue: 0.30, alpha: 1),    // green
        UIColor(red: 0.95, green: 0.75, blue: 0.05, alpha: 1),   // yellow
        UIColor(red: 0.7, green: 0.15, blue: 0.75, alpha: 1),    // purple
    ]
    for (i, color) in palette.enumerated() {
        let node = RaceGame.buildCar(bodyColor: color, accentWhite: false)
        scene.rootNode.addChildNode(node)
        let offset = Float(i + 1) * 0.04   // staggered start
        let lateral = Float([-3.5, 3.5, -1.8, 1.8][i])
        let target = Float.random(in: 42 ... 55)
        opponents.append(Opponent(node: node,
                                  trackOffset: -offset,   // start a bit behind
                                  lateral: lateral,
                                  speed: 0,
                                  targetSpeed: target))
    }
}

// returns world position + heading at a given normalized arc-length s in 0..1
private func sampleTrack(_ s: Float) -> (pos: SIMD2<Float>, heading: Float) {
    let n = trackPoints.count
    let total = Float(n)
    let raw = ((s.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)) * total
    let i0 = Int(floor(raw)) % n
    let i1 = (i0 + 1) % n
    let t = raw - floor(raw)
    let a = trackPoints[i0]
    let b = trackPoints[i1]
    let p = SIMD2<Float>(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    let h = atan2(b.y - a.y, b.x - a.x)
    return (p, h)
}

// MARK: - Car factory
private static func buildCar(bodyColor: UIColor, accentWhite: Bool) -> SCNNode {
    let car = SCNNode()

    let bodyMat = SCNMaterial()
    bodyMat.lightingModel = .physicallyBased
    bodyMat.diffuse.contents = bodyColor
    bodyMat.metalness.contents = 0.45
    bodyMat.roughness.contents = 0.3

    let whiteMat = SCNMaterial()
    whiteMat.lightingModel = .physicallyBased
    whiteMat.diffuse.contents = UIColor.white
    whiteMat.roughness.contents = 0.4

    let blackMat = SCNMaterial()
    blackMat.lightingModel = .physicallyBased
    blackMat.diffuse.contents = UIColor.black
    blackMat.roughness.contents = 0.3

    let body = SCNBox(width: 1.0, height: 0.3, length: 3.6, chamferRadius: 0.15)
    body.materials = [bodyMat]
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3(0, 0.4, 0)
    car.addChildNode(bodyNode)

    if accentWhite {
        let stripe = SCNBox(width: 1.02, height: 0.04, length: 1.6, chamferRadius: 0.02)
        stripe.materials = [whiteMat]
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, 0.55, 0.4)
        car.addChildNode(stripeNode)
    }

    let cockpit = SCNBox(width: 0.55, height: 0.3, length: 0.9, chamferRadius: 0.18)
    cockpit.materials = [blackMat]
    let cockpitNode = SCNNode(geometry: cockpit)
    cockpitNode.position = SCNVector3(0, 0.7, 0.1)
    car.addChildNode(cockpitNode)

    let helmet = SCNSphere(radius: 0.18)
    helmet.materials = [accentWhite ? whiteMat : blackMat]
    let helmetNode = SCNNode(geometry: helmet)
    helmetNode.position = SCNVector3(0, 0.95, 0.05)
    car.addChildNode(helmetNode)

    let nose = SCNBox(width: 0.45, height: 0.18, length: 1.2, chamferRadius: 0.1)
    nose.materials = [bodyMat]
    let noseNode = SCNNode(geometry: nose)
    noseNode.position = SCNVector3(0, 0.32, -2.0)
    car.addChildNode(noseNode)

    if accentWhite {
        let noseTip = SCNBox(width: 0.4, height: 0.16, length: 0.35, chamferRadius: 0.08)
        noseTip.materials = [whiteMat]
        let noseTipNode = SCNNode(geometry: noseTip)
        noseTipNode.position = SCNVector3(0, 0.32, -2.65)
        car.addChildNode(noseTipNode)
    }

    let frontWing = SCNBox(width: 2.0, height: 0.06, length: 0.5, chamferRadius: 0.02)
    frontWing.materials = [bodyMat]
    let frontWingNode = SCNNode(geometry: frontWing)
    frontWingNode.position = SCNVector3(0, 0.2, -2.5)
    car.addChildNode(frontWingNode)

    let rearWingMain = SCNBox(width: 1.6, height: 0.05, length: 0.35, chamferRadius: 0.02)
    rearWingMain.materials = [bodyMat]
    let rearWingNode = SCNNode(geometry: rearWingMain)
    rearWingNode.position = SCNVector3(0, 0.95, 1.7)
    car.addChildNode(rearWingNode)

    let endplate = SCNBox(width: 0.05, height: 0.55, length: 0.3, chamferRadius: 0.02)
    endplate.materials = [accentWhite ? whiteMat : bodyMat]
    let epL = SCNNode(geometry: endplate)
    epL.position = SCNVector3(-0.8, 0.72, 1.7)
    car.addChildNode(epL)
    let epR = SCNNode(geometry: endplate.copy() as! SCNGeometry)
    epR.position = SCNVector3(0.8, 0.72, 1.7)
    car.addChildNode(epR)

    let support = SCNBox(width: 0.05, height: 0.55, length: 0.1, chamferRadius: 0)
    support.materials = [blackMat]
    let supL = SCNNode(geometry: support)
    supL.position = SCNVector3(-0.35, 0.7, 1.7)
    car.addChildNode(supL)
    let supR = SCNNode(geometry: support.copy() as! SCNGeometry)
    supR.position = SCNVector3(0.35, 0.7, 1.7)
    car.addChildNode(supR)

    let wheelMat = SCNMaterial()
    wheelMat.lightingModel = .physicallyBased
    wheelMat.diffuse.contents = UIColor.black
    wheelMat.roughness.contents = 0.9
    let wheelPositions: [(Float, Float)] = [
        (-0.65, -1.4), ( 0.65, -1.4),
        (-0.65,  1.3), ( 0.65,  1.3),
    ]
    for (x, z) in wheelPositions {
        let wheel = SCNCylinder(radius: 0.35, height: 0.35)
        wheel.materials = [wheelMat]
        let w = SCNNode(geometry: wheel)
        w.position = SCNVector3(x, 0.35, z)
        w.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        car.addChildNode(w)
    }

    return car
}

// MARK: - Render loop
func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    if lastTime == 0 {
        lastTime = time
        raceStartTime = time
        lapStartTime = time
    }
    let dt = Float(min(0.05, time - lastTime))
    lastTime = time

    if !finished {
        elapsed = time - raceStartTime
    }

    let throttle: Float = throttlePressed ? 1.0 : 0.0
    let brake: Float = brakingPressed ? 1.0 : 0.0
    let steer: Float = (steerLeftPressed ? -1 : 0) + (steerRightPressed ? 1 : 0)

    // Turbo logic
    let wantTurbo = turboPressed && turboFuel > 0.02 && !finished
    let isTurbo = wantTurbo && speed > 5
    if isTurbo {
        turboFuel -= 0.18 * dt   // ~5.5s of full turbo
        if turboFuel < 0 { turboFuel = 0 }
    } else {
        // regen
        turboFuel += 0.06 * dt
        if turboFuel > 1 { turboFuel = 1 }
    }
    let currentMaxFwd = isTurbo ? turboMaxSpeed : baseMaxSpeed
    let engineAccel: Float = isTurbo ? 30.0 : 18.0
    let brakeAccel: Float = 28.0
    let drag: Float = 0.45
    let rollingResistance: Float = 1.6

    if !finished {
        speed += throttle * engineAccel * dt
        speed -= brake * brakeAccel * dt * (speed > 0 ? 1 : -1)

        if speed > -maxSpeedRev && brake > 0 && speed < 0.5 && throttle == 0 {
            speed -= brakeAccel * 0.5 * dt
        }

        speed -= drag * speed * abs(speed) / max(currentMaxFwd, 1) * dt * 8
        if abs(speed) > 0.01 {
            speed -= rollingResistance * (speed > 0 ? 1 : -1) * dt
        } else {
            speed = 0
        }

        speed = min(max(speed, -maxSpeedRev), currentMaxFwd)

        let steerSpeedFactor = max(0.25, min(1.0, abs(speed) / 25))
        let turnRate: Float = 1.9 * steer * steerSpeedFactor
        heading += turnRate * dt * (speed >= 0 ? 1 : -1)

        let dx = cos(heading) * speed * dt
        let dz = sin(heading) * speed * dt
        position.x += dx
        position.y += dz

        let (onTrack, _) = trackInfo(at: position)
        if !onTrack {
            speed *= 0.965
        }

        // Collisions with opponents (soft push-back)
        for opp in opponents {
            let opPos = SIMD2<Float>(opp.node.position.x, opp.node.position.z)
            let d = simd_distance(position, opPos)
            if d < 2.3 {
                let push = (position - opPos) / max(d, 0.001) * (2.3 - d) * 0.6
                position += push
                speed *= 0.92
            }
        }
    }

    // Apply transform - player
    carNode.position = SCNVector3(position.x, 0.4, position.y)
    carNode.eulerAngles = SCNVector3(0, -heading + .pi / 2, 0)

    // Opponent AI
    for i in opponents.indices {
        if !finished {
            opponents[i].speed += (opponents[i].targetSpeed - opponents[i].speed) * 0.6 * dt
            let advance = opponents[i].speed * dt / max(trackLength, 1)
            opponents[i].trackOffset += advance
        }
        let s = opponents[i].trackOffset.truncatingRemainder(dividingBy: 1)
        let (pos, h) = sampleTrack(s)
        // lateral offset perpendicular to heading
        let lx = pos.x + cos(h + .pi / 2) * opponents[i].lateral
        let lz = pos.y + sin(h + .pi / 2) * opponents[i].lateral
        opponents[i].node.position = SCNVector3(lx, 0.4, lz)
        opponents[i].node.eulerAngles = SCNVector3(0, -h + .pi / 2, 0)
    }

    // Camera: chase with FOV punch on turbo
    let camDist: Float = isTurbo ? 9.5 : 8.0
    let camHeight: Float = isTurbo ? 3.2 : 3.5
    let camX = position.x - cos(heading) * camDist
    let camZ = position.y - sin(heading) * camDist
    let targetCamPos = SCNVector3(camX, camHeight, camZ)
    let cp = cameraNode.position
    let smooth: Float = 0.15
    cameraNode.position = SCNVector3(
        cp.x + (targetCamPos.x - cp.x) * smooth,
        cp.y + (targetCamPos.y - cp.y) * smooth,
        cp.z + (targetCamPos.z - cp.z) * smooth
    )
    let lookAt = SCNVector3(position.x + cos(heading) * 4, 0.8, position.y + sin(heading) * 4)
    cameraNode.look(at: lookAt, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

    if let cam = cameraNode.camera {
        let targetFOV: CGFloat = isTurbo ? 100 : 85
        cam.fieldOfView += (targetFOV - cam.fieldOfView) * 0.1
        cam.motionBlurIntensity = isTurbo ? 0.6 : 0.25
    }

    // Lap detection
    let toHalf = simd_distance(position, halfwayPoint)
    let toStart = simd_distance(position, startLine)
    if !hasCrossedHalfway && toHalf < 8 {
        hasCrossedHalfway = true
    }
    if hasCrossedHalfway && toStart < 6 {
        let lapTime = time - lapStartTime
        if bestLap == nil || lapTime < (bestLap ?? .infinity) {
            bestLap = lapTime
        }
        hasCrossedHalfway = false
        lapStartTime = time
        if currentLap >= totalLaps {
            finished = true
        } else {
            currentLap += 1
        }
    }

    // HUD publish on main thread
    let kmh = max(0, Double(speed)) * 3.6
    let fuel = Double(turboFuel)
    let active = isTurbo
    DispatchQueue.main.async {
        self.speedKmh = kmh
        self.turboAvailable = fuel
        self.turboActive = active
    }
}

private func trackInfo(at p: SIMD2<Float>) -> (onTrack: Bool, segmentIndex: Int) {
    var minD: Float = .infinity
    var idx = 0
    for i in 0..<trackPoints.count {
        let a = trackPoints[i]
        let b = trackPoints[(i + 1) % trackPoints.count]
        let d = distancePointToSegment(p, a, b)
        if d < minD { minD = d; idx = i }
    }
    return (minD <= trackWidth / 2 + 0.5, idx)
}

private func distancePointToSegment(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let ab = b - a
    let ap = p - a
    let t = max(0, min(1, simd_dot(ap, ab) / max(simd_dot(ab, ab), 1e-6)))
    let proj = a + ab * t
    return simd_distance(p, proj)
}
}
