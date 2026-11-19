//  Transcript.swift
//  Yattee
//  Converts timed caption files into readable, exportable text.

import Foundation

struct Transcript: Hashable, Sendable {
    let text: String

    init(captions: String) throws(TranscriptError) {
        let source = captions.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        for block in source.components(separatedBy: "\n\n") {
            let rows = block.components(separatedBy: "\n")
            guard let timing = rows.firstIndex(where: { $0.contains(" --> ") }),
                  timing + 1 < rows.count else { continue }
            let content = rows[(timing + 1)...].joined(separator: " ")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty, lines.last != content { lines.append(content) }
        }
        guard !lines.isEmpty else { throw .unsupportedCaptions }
        text = lines.joined(separator: "\n")
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
