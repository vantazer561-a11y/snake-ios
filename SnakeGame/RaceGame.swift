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

// MARK: - Input flags (set by RaceView)
var throttlePressed: Bool = false
var brakingPressed: Bool = false
var steerLeftPressed: Bool = false
var steerRightPressed: Bool = false

// MARK: - Scene
let scene: SCNScene
let cameraNode: SCNNode
weak var sceneView: SCNView?

// MARK: - Track (closed loop as a polyline of waypoints)
private let trackPoints: [SIMD2<Float>]
private let trackWidth: Float = 14.0

// MARK: - Car state
private let carNode: SCNNode
private var position: SIMD2<Float>
private var heading: Float
private var speed: Float = 0
private let maxSpeedFwd: Float = 75
private let maxSpeedRev: Float = 12

// MARK: - Lap tracking
private var lapStartTime: TimeInterval = 0
private var raceStartTime: TimeInterval = 0
private var lastTime: TimeInterval = 0
private var hasCrossedHalfway: Bool = false
private let startLine: SIMD2<Float>
private let halfwayPoint: SIMD2<Float>

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

    self.carNode = RaceGame.buildCar()
    self.position = pts[0]
    let next = pts[1]
    let dx = next.x - pts[0].x
    let dz = next.y - pts[0].y
    self.heading = atan2(dz, dx)

    let cam = SCNCamera()
    cam.zFar = 800
    cam.zNear = 0.3
    cam.fieldOfView = 65
    let camNode = SCNNode()
    camNode.camera = cam
    self.cameraNode = camNode

    super.init()

    buildEnvironment()
    buildTrack()

    carNode.position = SCNVector3(position.x, 0.4, position.y)
    carNode.eulerAngles = SCNVector3(0, -heading + .pi / 2, 0)
    scene.rootNode.addChildNode(carNode)
    scene.rootNode.addChildNode(camNode)
}

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
}

private func buildEnvironment() {
    let sun = SCNLight()
    sun.type = .directional
    sun.intensity = 1100
    sun.castsShadow = true
    sun.shadowMode = .deferred
    sun.shadowRadius = 6
    sun.shadowSampleCount = 8
    let sunNode = SCNNode()
    sunNode.light = sun
    sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
    scene.rootNode.addChildNode(sunNode)

    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.intensity = 350
    ambient.color = UIColor(white: 0.85, alpha: 1)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    let ground = SCNFloor()
    ground.reflectivity = 0.02
    let groundMat = SCNMaterial()
    groundMat.diffuse.contents = UIColor(red: 0.25, green: 0.55, blue: 0.22, alpha: 1)
    groundMat.locksAmbientWithDiffuse = true
    ground.materials = [groundMat]
    let groundNode = SCNNode(geometry: ground)
    groundNode.position = SCNVector3(0, 0, 0)
    scene.rootNode.addChildNode(groundNode)

    scene.fogColor = UIColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1.0)
    scene.fogStartDistance = 220
    scene.fogEndDistance = 600
}

private func buildTrack() {
    let asphaltMat = SCNMaterial()
    asphaltMat.diffuse.contents = UIColor(white: 0.18, alpha: 1)
    asphaltMat.locksAmbientWithDiffuse = true

    let whiteMat = SCNMaterial()
    whiteMat.diffuse.contents = UIColor.white

    let redMat = SCNMaterial()
    redMat.diffuse.contents = UIColor.red

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

    let line = SCNBox(width: CGFloat(trackWidth), height: 0.06, length: 1.2, chamferRadius: 0)
    let lineMat = SCNMaterial()
    lineMat.diffuse.contents = UIColor.white
    line.materials = [lineMat]
    let lineNode = SCNNode(geometry: line)
    lineNode.position = SCNVector3(startLine.x, 0.06, startLine.y)
    let next = trackPoints[1]
    let ang = atan2(next.y - startLine.y, next.x - startLine.x)
    lineNode.eulerAngles = SCNVector3(0, -ang + .pi / 2, 0)
    scene.rootNode.addChildNode(lineNode)

    let standMat = SCNMaterial()
    standMat.diffuse.contents = UIColor(white: 0.7, alpha: 1)
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

        let pole = SCNCylinder(radius: 0.1, height: 6)
        let poleMat = SCNMaterial()
        poleMat.diffuse.contents = UIColor.darkGray
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(p.x + cos(dirAng + .pi / 2) * (off - 2), 3, p.y + sin(dirAng + .pi / 2) * (off - 2))
        scene.rootNode.addChildNode(poleNode)

        let flag = SCNBox(width: 2, height: 1.2, length: 0.05, chamferRadius: 0)
        let flagMat = SCNMaterial()
        flagMat.diffuse.contents = (i % 32 == 0) ? UIColor.red : UIColor.yellow
        flag.materials = [flagMat]
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(poleNode.position.x + 1, 5.2, poleNode.position.z)
        scene.rootNode.addChildNode(flagNode)
    }
}

private static func buildCar() -> SCNNode {
    let car = SCNNode()

    // Burgundy body (per reference)
    let bodyMat = SCNMaterial()
    bodyMat.diffuse.contents = UIColor(red: 0.55, green: 0.06, blue: 0.10, alpha: 1)
    bodyMat.metalness.contents = 0.4
    bodyMat.roughness.contents = 0.35

    // White accent
    let whiteMat = SCNMaterial()
    whiteMat.diffuse.contents = UIColor.white
    whiteMat.roughness.contents = 0.4

    let blackMat = SCNMaterial()
    blackMat.diffuse.contents = UIColor.black

    // body
    let body = SCNBox(width: 1.0, height: 0.3, length: 3.6, chamferRadius: 0.15)
    body.materials = [bodyMat]
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3(0, 0.4, 0)
    car.addChildNode(bodyNode)

    // sidepod white stripe
    let stripe = SCNBox(width: 1.02, height: 0.04, length: 1.6, chamferRadius: 0.02)
    stripe.materials = [whiteMat]
    let stripeNode = SCNNode(geometry: stripe)
    stripeNode.position = SCNVector3(0, 0.55, 0.4)
    car.addChildNode(stripeNode)

    // cockpit
    let cockpit = SCNBox(width: 0.55, height: 0.3, length: 0.9, chamferRadius: 0.18)
    cockpit.materials = [blackMat]
    let cockpitNode = SCNNode(geometry: cockpit)
    cockpitNode.position = SCNVector3(0, 0.7, 0.1)
    car.addChildNode(cockpitNode)

    // driver helmet (white sphere)
    let helmet = SCNSphere(radius: 0.18)
    helmet.materials = [whiteMat]
    let helmetNode = SCNNode(geometry: helmet)
    helmetNode.position = SCNVector3(0, 0.95, 0.05)
    car.addChildNode(helmetNode)

    // nose (burgundy)
    let nose = SCNBox(width: 0.45, height: 0.18, length: 1.2, chamferRadius: 0.1)
    nose.materials = [bodyMat]
    let noseNode = SCNNode(geometry: nose)
    noseNode.position = SCNVector3(0, 0.32, -2.0)
    car.addChildNode(noseNode)

    // nose tip (white)
    let noseTip = SCNBox(width: 0.4, height: 0.16, length: 0.35, chamferRadius: 0.08)
    noseTip.materials = [whiteMat]
    let noseTipNode = SCNNode(geometry: noseTip)
    noseTipNode.position = SCNVector3(0, 0.32, -2.65)
    car.addChildNode(noseTipNode)

    // front wing
    let frontWing = SCNBox(width: 2.0, height: 0.06, length: 0.5, chamferRadius: 0.02)
    frontWing.materials = [bodyMat]
    let frontWingNode = SCNNode(geometry: frontWing)
    frontWingNode.position = SCNVector3(0, 0.2, -2.5)
    car.addChildNode(frontWingNode)

    // rear wing
    let rearWingMain = SCNBox(width: 1.6, height: 0.05, length: 0.35, chamferRadius: 0.02)
    rearWingMain.materials = [bodyMat]
    let rearWingNode = SCNNode(geometry: rearWingMain)
    rearWingNode.position = SCNVector3(0, 0.95, 1.7)
    car.addChildNode(rearWingNode)

    // rear wing endplates (white)
    let endplate = SCNBox(width: 0.05, height: 0.55, length: 0.3, chamferRadius: 0.02)
    endplate.materials = [whiteMat]
    let epL = SCNNode(geometry: endplate)
    epL.position = SCNVector3(-0.8, 0.72, 1.7)
    car.addChildNode(epL)
    let epR = SCNNode(geometry: endplate.copy() as! SCNGeometry)
    epR.position = SCNVector3(0.8, 0.72, 1.7)
    car.addChildNode(epR)

    // rear wing supports
    let support = SCNBox(width: 0.05, height: 0.55, length: 0.1, chamferRadius: 0)
    support.materials = [blackMat]
    let supL = SCNNode(geometry: support)
    supL.position = SCNVector3(-0.35, 0.7, 1.7)
    car.addChildNode(supL)
    let supR = SCNNode(geometry: support.copy() as! SCNGeometry)
    supR.position = SCNVector3(0.35, 0.7, 1.7)
    car.addChildNode(supR)

    // wheels
    let wheelMat = SCNMaterial()
    wheelMat.diffuse.contents = UIColor.black
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

    let engineAccel: Float = 18.0
    let brakeAccel: Float = 28.0
    let drag: Float = 0.45
    let rollingResistance: Float = 1.6

    if !finished {
        speed += throttle * engineAccel * dt
        speed -= brake * brakeAccel * dt * (speed > 0 ? 1 : -1)

        if speed > -maxSpeedRev && brake > 0 && speed < 0.5 && throttle == 0 {
            speed -= brakeAccel * 0.5 * dt
        }

        speed -= drag * speed * abs(speed) / max(maxSpeedFwd, 1) * dt * 8
        if abs(speed) > 0.01 {
            speed -= rollingResistance * (speed > 0 ? 1 : -1) * dt
        } else {
            speed = 0
        }

        speed = min(max(speed, -maxSpeedRev), maxSpeedFwd)

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
    }

    carNode.position = SCNVector3(position.x, 0.4, position.y)
    carNode.eulerAngles = SCNVector3(0, -heading + .pi / 2, 0)

    let camDist: Float = 8.0
    let camHeight: Float = 3.5
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

    let kmh = max(0, Double(speed)) * 3.6
    DispatchQueue.main.async {
        self.speedKmh = kmh
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
