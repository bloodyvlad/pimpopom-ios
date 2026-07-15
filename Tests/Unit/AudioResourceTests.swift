import AVFoundation
import XCTest

@testable import PimPoPom

final class AudioResourceTests: XCTestCase {
    func testEveryThemeMusicLoopIsBundledAndTwelveSeconds() throws {
        for themeID in ["classic", "disco", "light", "pixel"] {
            let manifest = ThemeAudioManifest.resolve(themeID)
            for fileName in [manifest.menuFile, manifest.gameplayFile] {
                let file = try audioFile(named: fileName)
                XCTAssertEqual(file.processingFormat.sampleRate, 48_000)
                XCTAssertEqual(file.processingFormat.channelCount, 2)
                XCTAssertEqual(file.length, 576_000, "Unexpected loop length: \(fileName)")
            }
        }
    }

    func testEveryThemeToneBankHasSixteenHalfSecondSlots() throws {
        for themeID in ["classic", "disco", "light", "pixel"] {
            let fileName = ThemeAudioManifest.resolve(themeID).toneBankFile
            let file = try audioFile(named: fileName)
            XCTAssertEqual(file.processingFormat.sampleRate, 48_000)
            XCTAssertEqual(file.processingFormat.channelCount, 1)
            XCTAssertEqual(file.length, 384_000, "Unexpected tone-bank length: \(fileName)")
        }
    }

    func testSharedSoundEffectsAreBundledAsMonoPCM() throws {
        let loss = try audioFile(named: "audio-oops.wav")
        XCTAssertEqual(loss.processingFormat.sampleRate, 48_000)
        XCTAssertEqual(loss.processingFormat.channelCount, 1)
        XCTAssertEqual(loss.length, 29_760)

        let sting = try audioFile(named: "audio-pimpopom-sting.wav")
        XCTAssertEqual(sting.processingFormat.sampleRate, 48_000)
        XCTAssertEqual(sting.processingFormat.channelCount, 1)
        XCTAssertGreaterThan(sting.length, 51_000)
        XCTAssertLessThan(sting.length, 52_000)
    }

    private func audioFile(named fileName: String) throws -> AVAudioFile {
        let path = fileName as NSString
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: path.deletingPathExtension,
                withExtension: path.pathExtension
            ),
            "Missing bundled audio: \(fileName)"
        )
        return try AVAudioFile(forReading: url)
    }
}
