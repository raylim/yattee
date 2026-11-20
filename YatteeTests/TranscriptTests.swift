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
        #expect(transcript.text == "Hello & welcome. Another line. And more.")
    }

    @Test func readsSRTAndRemovesRepeatedCues() throws {
        let transcript = try Transcript(captions: "1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n2\r\n00:00:02,000 --> 00:00:03,000\r\nHello\r\n")
        #expect(transcript.text == "Hello")
    }

    @Test func mergesRollingAutoCaptions() throws {
        let transcript = try Transcript(captions: """
        WEBVTT

        00:00:00.000 --> 00:00:03.000
        <c>Hello</c><00:00:01.000> everyone

        00:00:01.000 --> 00:00:04.000
        Hello everyone
        welcome to this video.

        00:00:03.000 --> 00:00:06.000
        welcome to this video.
        Today we talk about captions.
        """)
        #expect(transcript.text == "Hello everyone welcome to this video. Today we talk about captions.")
    }

    @Test func preservesRepetitionAfterPause() throws {
        let transcript = try Transcript(captions: """
        00:00:00.000 --> 00:00:01.000
        Try again.

        00:00:04.000 --> 00:00:05.000
        Try again.
        """)
        #expect(transcript.text == "Try again.\n\nTry again.")
    }

    @Test func decodesEntitiesWithoutDoubleDecoding() throws {
        let transcript = try Transcript(captions: """
        00:00:00.000 --> 00:00:01.000
        It&#39;s &#x2014; &quot;clear&quot; &amp;lt;code&amp;gt;.
        """)
        #expect(transcript.text == "It's — \"clear\" &lt;code&gt;.")
    }

    @Test func preservesRepeatedWordsWithinSpeech() throws {
        let transcript = try Transcript(captions: """
        00:00:00.000 --> 00:00:01.000
        This is very very good.

        00:00:01.500 --> 00:00:02.500
        Very very good.
        """)
        #expect(transcript.text == "This is very very good. Very very good.")
    }

    @Test func rejectsEmptyOrUnsupportedCaptions() {
        #expect(throws: TranscriptError.unsupportedCaptions) { try Transcript(captions: "WEBVTT\n\n") }
        #expect(throws: TranscriptError.unsupportedCaptions) { try Transcript(captions: "<html>Error</html>") }
    }
}
