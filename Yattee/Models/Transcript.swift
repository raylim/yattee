//  Transcript.swift
//  Yattee
//  Converts timed caption files into readable, exportable text.

import Foundation

struct Transcript: Hashable, Sendable {
    let text: String

    init(captions: String) throws(TranscriptError) {
        let source = captions.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var paragraphs: [String] = []
        var words: [String] = []
        var previousEnd: Double?
        var cueCount = 0
        var removedWords = 0

        for block in source.components(separatedBy: "\n\n") {
            let rows = block.components(separatedBy: "\n")
            guard let timing = rows.firstIndex(where: { $0.contains("-->") }),
                  timing + 1 < rows.count else { continue }
            let times = rows[timing].components(separatedBy: "-->")
            guard times.count == 2,
                  let start = Self.seconds(times[0]), let end = Self.seconds(times[1]),
                  end >= start else { continue }
            let content = Self.clean(rows[(timing + 1)...].joined(separator: " "))
            let incoming = content.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard !incoming.isEmpty else { continue }
            cueCount += 1

            // Auto captions are rolling windows: each cue often includes the
            // previous line plus new words. Only merge temporally overlapping
            // windows, so repetitions spoken later remain in the transcript.
            let overlaps = previousEnd.map { start < $0 + 0.05 } ?? false
            var overlap = 0
            if overlaps {
                let limit = min(words.count, incoming.count)
                if limit > 0 {
                    for count in stride(from: limit, through: 1, by: -1) {
                        if words.suffix(count).map({ $0.lowercased() })
                            == incoming.prefix(count).map({ $0.lowercased() }) {
                            overlap = count
                            break
                        }
                    }
                }
            }
            removedWords += overlap
            let newWords = Array(incoming.dropFirst(overlap))
            let pause = previousEnd.map { start - $0 >= 1.5 } ?? false
            let sentenceBoundary = words.last.map { $0.hasSuffix(".") || $0.hasSuffix("?") || $0.hasSuffix("!") } ?? false
            if !words.isEmpty, !newWords.isEmpty,
               pause || (words.count >= 80 && sentenceBoundary) || words.count >= 160 {
                paragraphs.append(words.joined(separator: " "))
                words = []
            }
            words.append(contentsOf: newWords)
            previousEnd = end
        }
        if !words.isEmpty { paragraphs.append(words.joined(separator: " ")) }
        guard !paragraphs.isEmpty else { throw .unsupportedCaptions }
        text = paragraphs.joined(separator: "\n\n")
        LoggingService.shared.debug("Transcript: parsed \(cueCount) cues, removed \(removedWords) overlapping words", category: .api)
    }

    private static func seconds(_ value: String) -> Double? {
        guard let timestamp = value.split(whereSeparator: { $0.isWhitespace }).first else { return nil }
        let parts = timestamp.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard (2...3).contains(parts.count) else { return nil }
        var result = 0.0
        for part in parts {
            guard let number = Double(part), number.isFinite, number >= 0 else { return nil }
            result = result * 60 + number
        }
        return result
    }

    private static func clean(_ value: String) -> String {
        let stripped = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "lrm": "", "rlm": ""]
        guard let regex = try? NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);") else { return stripped }
        var result = stripped
        for match in regex.matches(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)).reversed() {
            guard let range = Range(match.range, in: stripped),
                  let nameRange = Range(match.range(at: 1), in: stripped) else { continue }
            let name = String(stripped[nameRange])
            var replacement = entities[name]
            if name.hasPrefix("#") {
                let hexadecimal = name.hasPrefix("#x")
                let digits = String(name.dropFirst(hexadecimal ? 2 : 1))
                if let code = UInt32(digits, radix: hexadecimal ? 16 : 10), let scalar = UnicodeScalar(code) {
                    replacement = String(scalar)
                }
            }
            if let replacement { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }

}

enum TranscriptError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedCaptions
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedCaptions:
            String(localized: "These captions could not be read as a transcript. WebVTT and SRT captions are supported.")
        case .requestFailed:
            String(localized: "The captions could not be downloaded. Please try again.")
        }
    }
}

actor TranscriptService {
    func load(_ caption: Caption) async throws -> Transcript {
        do {
            let (data, response) = try await URLSession.shared.data(from: caption.url)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                  let text = String(data: data, encoding: .utf8) else {
                throw TranscriptError.requestFailed
            }
            return try Transcript(captions: text)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            LoggingService.shared.error("Transcript loading failed: \(error.localizedDescription)", category: .api)
            throw (error as? TranscriptError) ?? .requestFailed
        }
    }
}
