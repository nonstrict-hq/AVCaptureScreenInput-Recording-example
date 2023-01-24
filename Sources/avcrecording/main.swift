//
//  AVCaptureScreenInput-Recording-example
//
//  Created by Tom Lokhorst on 2023-01-18.
//

import AVFoundation
import CoreGraphics
import AppKit

// Create a screen recording
do {
    // Check for screen recording permission, make sure your terminal has screen recording permission
    if #available(macOS 11, *) {
        guard CGPreflightScreenCaptureAccess() else {
            throw RecordingError("No screen capture permission")
        }
    } else {
        // See: https://developer.apple.com/forums/thread/683860?answerId=684400022#684400022
        print("Screen capture authorization can't be checked on macOS 10.15.")
    }

    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("recording \(Date()).mov")
//    let cropRect = CGRect(x: 0, y: 0, width: 960, height: 540)
    let screenRecorder = try await ScreenRecorder(url: url, displayID: CGMainDisplayID(), cropRect: nil)

    print("Starting screen recording of main display")
    try await screenRecorder.start()

    print("Hit Return to end recording")
    _ = readLine()
    try await screenRecorder.stop()

    print("Recording ended, opening video")
    NSWorkspace.shared.open(url)
} catch {
    print("Error during recording:", error)
}



struct ScreenRecorder {
    private let captureSession = AVCaptureSession()
    private let output: AVCaptureMovieFileOutput
    private let url: URL
    private let delegate: RecordingDelegate

    init(url: URL, displayID: CGDirectDisplayID, cropRect: CGRect?) async throws {

        self.output = AVCaptureMovieFileOutput()
        self.url = url
        self.delegate = RecordingDelegate()

        // Create AVCaptureScreenInput for displayID
        guard let videoInput = AVCaptureScreenInput(displayID: displayID) else {
            throw RecordingError("Can't find \(displayID) as active display")
        }

        if let cropRect = cropRect {
            // AVFoundation uses bottom-left of screen as origin
            videoInput.cropRect = cropRect
        }


        // Add AVCaptureScreenInput as input AVCaptureSession
        guard captureSession.canAddInput(videoInput) else {
            throw RecordingError("Can't add input device to session")
        }
        captureSession.addInput(videoInput)


        // Add AVCaptureMovieFileOutput as output to AVCaptureSession
        guard captureSession.canAddOutput(output) else {
            throw RecordingError("Can't add output to session")
        }
        captureSession.addOutput(output)

        // Blocking call to start running the AVCaptureSession
        captureSession.startRunning()
    }

    func start() async throws {
        output.startRecording(to: url, recordingDelegate: delegate) // Note: potentially throws NSException
    }

    func stop() async throws {
        try await withCheckedThrowingContinuation { continuation in
            delegate.finishedContinuation = continuation
            output.stopRecording()
        }
        delegate.finishedContinuation = nil // Don't leak continuation

        // Blocking call to stop running the AVCaptureSession
        captureSession.stopRunning()
    }

    private class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        var finishedContinuation: CheckedContinuation<Void, Error>?

        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error {
                finishedContinuation?.resume(throwing: error)
            } else {
                finishedContinuation?.resume()
            }
        }
    }
}


struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) { self.debugDescription = debugDescription }
}
