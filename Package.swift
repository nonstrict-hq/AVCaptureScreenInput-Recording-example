// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "AVCaptureScreenInput-Recording-example",
    platforms: [ .macOS(.v10_15) ],
    targets: [
        .executableTarget(name: "avcrecording")
    ]
)
