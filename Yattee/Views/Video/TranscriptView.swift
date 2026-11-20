//  TranscriptView.swift
//  Yattee
//  Reads caption tracks and copies or exports their transcript.

import Foundation
import SwiftUI
#if !os(tvOS)
import UniformTypeIdentifiers

struct TranscriptView: View {
    let video: Video
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var captions: [Caption] = []
    @State private var selectedCaption: Caption?
    @State private var transcript: Transcript?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isExporting = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !captions.isEmpty {
                Picker("Language", selection: $selectedCaption) {
                    ForEach(captions) { caption in
                        Text(caption.label).tag(Optional(caption))
                    }
                }
            }
            if isLoading {
                ProgressView("Loading transcript…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
                Button("Retry") { Task { await load() } }
            } else if let transcript {
                VStack(alignment: .leading, spacing: 12) {
                    transcriptActions(transcript)
                }
                Text("\(transcript.text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(transcript.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                            Text(verbatim: paragraph)
                                .font(.body)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .frame(height: 320)
            } else {
                Text("No captions are available for this video. A transcript requires a caption track.")
                    .foregroundStyle(.secondary)
            }
        }
        .task { await load() }
        .task(id: selectedCaption) {
            guard let selectedCaption else { return }
            await loadTranscript(selectedCaption)
        }
        .fileExporter(isPresented: $isExporting, document: TranscriptDocument(text: transcript?.text ?? ""),
                      contentType: .plainText, defaultFilename: "\(video.id.videoID)-transcript") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func transcriptActions(_ transcript: Transcript) -> some View {
        Button(copied ? "Copied" : "Copy", systemImage: "doc.on.doc") {
            #if os(iOS)
            UIPasteboard.general.string = transcript.text
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript.text, forType: .string)
            #endif
            copied = true
        }
        Button("Save as Text", systemImage: "square.and.arrow.down") { isExporting = true }
        ShareLink(item: transcript.text, subject: Text(video.title)) {
            Label("Export to App", systemImage: "square.and.arrow.up")
        }
    }

    private func load() async {
        guard let appEnvironment else {
            LoggingService.shared.error("Transcript: app environment unavailable", category: .api)
            errorMessage = String(localized: "Transcript loading is unavailable. Close this page and try again.")
            return
        }
        LoggingService.shared.debug("Transcript: discovering caption tracks", category: .api)
        isLoading = true
        errorMessage = nil
        do {
            if captions.isEmpty {
                if appEnvironment.playerService.state.currentVideo?.id == video.id {
                    captions = appEnvironment.playerService.availableCaptions
                }
                if captions.isEmpty {
                    if case .extracted(_, let url) = video.id.source,
                       let instance = appEnvironment.instancesManager.yatteeServerInstance {
                        let (_, _, tracks) = try await appEnvironment.contentService.extractURL(url, instance: instance)
                        captions = tracks
                    } else if let instance = appEnvironment.instancesManager.instance(for: video) {
                        let result = try await appEnvironment.contentService.videoWithProxyStreamsAndCaptionsAndStoryboards(
                            id: video.id.videoID, instance: instance)
                        captions = result.captions
                    }
                }
            }
            LoggingService.shared.debug("Transcript: found \(captions.count) caption tracks", category: .api)
            if let selectedCaption {
                await loadTranscript(selectedCaption)
            } else {
                selectedCaption = captions.first { $0.baseLanguageCode.lowercased() == "en" && !$0.isAutoGenerated }
                    ?? captions.first { $0.baseLanguageCode.lowercased() == "en" }
                    ?? captions.first
                isLoading = selectedCaption != nil
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadTranscript(_ caption: Caption) async {
        isLoading = true
        transcript = nil
        copied = false
        errorMessage = nil
        LoggingService.shared.debug("Transcript: loading language \(caption.languageCode), auto-generated: \(caption.isAutoGenerated)", category: .api)
        do {
            let result = try await TranscriptService().load(caption)
            try Task.checkCancellation()
            LoggingService.shared.debug("Transcript: loaded \(result.text.count) characters", category: .api)
            transcript = result
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TranscriptDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    let text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
#endif
