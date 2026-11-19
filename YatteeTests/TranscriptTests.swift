//  TranscriptTests.swift
//  Yattee
//  Verifies caption conversion for transcript reading and export.

import Foundation
import Testing
@testable import Yattee

struct TranscriptTests {
    @Test func readsWebVTT() throws {
        let transcript = try Transcript(captions: """
        WEBVTT

        00:00:01.000 --> 00:00:02.000 align:start
        <v Speaker>Hello &amp; welcome.</v>

        00:00:02.000 --> 00:00:03.000
        Another line.
        And more.
        """)
        #expect(transcript.text == "Hello & welcome.\nAnother line. And more.")
    }

    @Test func readsSRTAndRemovesRepeatedCues() throws {
        let transcript = try Transcript(captions: "1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n2\r\n00:00:02,000 --> 00:00:03,000\r\nHello\r\n")
        #expect(transcript.text == "Hello")
    }

    @Test func rejectsEmptyOrUnsupportedCaptions() {
        #expect(throws: TranscriptError.unsupportedCaptions) { try Transcript(captions: "WEBVTT\n\n") }
        #expect(throws: TranscriptError.unsupportedCaptions) { try Transcript(captions: "<html>Error</html>") }
    }
}
