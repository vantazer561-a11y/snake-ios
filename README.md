# F1 Racing iOS

3D Formula-1 style racing game for iOS built with SwiftUI + SceneKit.

## Features
- 3D burgundy/white F1 car (chassis, nose, front/rear wings, helmet, wheels)
- Closed oval circuit with red/white kerbs, start/finish line, grandstands, flags
- Realistic-ish driving physics: throttle, brake, steering, drag, off-track grass penalty
- 3-lap race with lap timer and best-lap tracking
- HUD: current lap, elapsed time, best lap, speed in km/h
- Touch controls: GAS (right), BRAKE (left), steering ◀ ▶
- Chase camera that smoothly follows the car

## Tech
- SwiftUI app shell
- SceneKit 3D rendering at 60 fps
- No third-party dependencies
- iOS 15+

## Build
CI workflow (.github/workflows/ios-build.yml) builds an unsigned `.ipa` on macOS-15 / Xcode 16 and uploads it as artifact `SnakeGame-unsigned-ipa`.
