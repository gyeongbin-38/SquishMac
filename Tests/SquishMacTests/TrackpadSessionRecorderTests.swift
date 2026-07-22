import XCTest
@testable import SquishMac

final class TrackpadSessionRecorderTests: XCTestCase {
    func testRecordedSessionRoundTripsAsVersionedJSON() throws {
        let recorder = TrackpadSessionRecorder(maximumSampleCount: 10)
        let start = Date(timeIntervalSince1970: 1_000)
        let trigger = TrackpadGestureTrigger(kind: .slimeKnead, intensity: 0.7, label: "Knead")

        recorder.start(tuning: TrackpadTuning(response: 1.2, soundDensity: 0.8), at: start)
        recorder.append(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.5,
            forceStage: 1,
            movement: 0.2,
            spread: 0.7,
            intensity: 0.65,
            touches: [TrackpadTouchPoint(id: "finger-1", x: 0.2, y: 0.8)],
            trigger: trigger,
            at: start.addingTimeInterval(0.25)
        )
        recorder.stop(at: start.addingTimeInterval(1))

        let data = try recorder.encodedSession()
        let session = try TrackpadSessionRecorder.decoder().decode(TrackpadSessionFile.self, from: data)

        XCTAssertEqual(session.schemaVersion, 1)
        XCTAssertEqual(session.samples.count, 1)
        XCTAssertEqual(session.events.count, 1)
        XCTAssertEqual(session.samples[0].relativeTime, 0.25, accuracy: 0.0001)
        XCTAssertEqual(session.samples[0].touches[0].id, "finger-1")
        XCTAssertEqual(session.events[0].kind, .slimeKnead)
        XCTAssertEqual(session.tuning, TrackpadTuning(response: 1.2, soundDensity: 0.8))
    }

    func testRecorderStopsAtSafetyCapacity() {
        let recorder = TrackpadSessionRecorder(maximumSampleCount: 2)
        let start = Date(timeIntervalSince1970: 2_000)
        recorder.start(tuning: .standard, at: start)

        for index in 0..<3 {
            recorder.append(
                mode: .twoThumbWaxCrush,
                fingerCount: 2,
                pressure: 0.4,
                forceStage: 1,
                movement: 0.1,
                spread: 0.3,
                intensity: 0.5,
                touches: [],
                trigger: nil,
                at: start.addingTimeInterval(Double(index) * 0.1)
            )
        }

        XCTAssertEqual(recorder.samples.count, 2)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(recorder.isAtCapacity)
    }

    func testEmptyRecorderCannotExport() {
        let recorder = TrackpadSessionRecorder()

        XCTAssertThrowsError(try recorder.encodedSession()) { error in
            XCTAssertEqual(error as? TrackpadSessionRecorderError, .noSamples)
        }
    }
}
