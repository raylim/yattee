//
//  CarPlaySceneDelegate.swift
//  Yattee
//
//  Provides CarPlay audio browsing using the shared playback services.
//

import Foundation
#if os(iOS)
import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate {
    private var interfaceController: CPInterfaceController?
    private var observationTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private let environment = AppEnvironment.shared
    private let queueTemplate = CPListTemplate(title: String(localized: "Queue"), sections: [])
    private let bookmarksTemplate = CPListTemplate(title: String(localized: "Bookmarks"), sections: [])
    private let historyTemplate = CPListTemplate(title: String(localized: "History"), sections: [])

    // MARK: - Scene Lifecycle

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self
        queueTemplate.tabImage = UIImage(systemName: "list.bullet")
        bookmarksTemplate.tabImage = UIImage(systemName: "bookmark")
        historyTemplate.tabImage = UIImage(systemName: "clock")
        refreshLists()
        interfaceController.setRootTemplate(
            CPTabBarTemplate(templates: [queueTemplate, bookmarksTemplate, historyTemplate]),
            animated: false
        ) { success, error in
            if !success {
                LoggingService.shared.error("CarPlay root template failed: \(error?.localizedDescription ?? "Unknown error")", category: .player)
            }
        }
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await observationChange {
                    _ = self.environment.playerService.state.queue
                    _ = self.environment.playerService.state.currentVideo
                    _ = self.environment.playerService.state.playbackState
                    _ = self.environment.dataManager.cachedBookmarkedVideoIDs
                }
                guard !Task.isCancelled else { return }
                self.refreshLists()
            }
        }
        LoggingService.shared.info("CarPlay connected", category: .player)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        observationTask?.cancel()
        observationTask = nil
        playbackTask?.cancel()
        playbackTask = nil
        interfaceController.delegate = nil
        self.interfaceController = nil
        LoggingService.shared.info("CarPlay disconnected", category: .player)
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        refreshLists()
    }

    // MARK: - Browsing

    private func refreshLists() {
        let state = environment.playerService.state
        var queueItems: [CPListItem] = []
        if let currentVideo = state.currentVideo {
            let item = CPListItem(text: currentVideo.title, detailText: String(localized: "Now Playing"))
            item.isPlaying = state.playbackState == .playing
            item.handler = { [weak self] _, completion in
                self?.showNowPlaying()
                completion()
            }
            queueItems.append(item)
        }
        queueItems += state.queue.prefix(CPListTemplate.maximumItemCount - queueItems.count).map { queued in
            let item = CPListItem(text: queued.video.title, detailText: queued.video.author.name)
            item.handler = { [weak self] _, completion in
                self?.startPlayback(completion: completion) { [weak self] in
                    guard let self else { return }
                    self.environment.settingsManager.audioOnlyModeEnabled = true
                    await self.environment.playerService.playQueueItem(id: queued.id)
                }
            }
            return item
        }
        update(queueTemplate, items: queueItems)
        update(bookmarksTemplate, items: environment.dataManager.bookmarks(limit: CPListTemplate.maximumItemCount).map { videoItem($0.toVideo()) })
        update(historyTemplate, items: environment.dataManager.watchHistory(limit: CPListTemplate.maximumItemCount).map { videoItem($0.toVideo()) })
        let buttons = state.currentVideo == nil ? [] : [CPBarButton(title: String(localized: "Now Playing")) { [weak self] _ in
            self?.showNowPlaying()
        }]
        for template in [queueTemplate, bookmarksTemplate, historyTemplate] {
            template.trailingNavigationBarButtons = buttons
        }
    }

    private func update(_ template: CPListTemplate, items: [CPListItem]) {
        template.emptyViewTitleVariants = [String(localized: "No items")]
        template.emptyViewSubtitleVariants = [String(localized: "Add content in Yattee on your iPhone.")]
        template.updateSections(items.isEmpty ? [] : [CPListSection(items: items)])
    }

    private func videoItem(_ video: Video) -> CPListItem {
        let item = CPListItem(text: video.title, detailText: video.author.name)
        item.handler = { [weak self] _, completion in
            self?.startPlayback(completion: completion) { [weak self] in
                guard let self else { return }
                self.environment.settingsManager.audioOnlyModeEnabled = true
                await self.environment.playerService.playPreferringDownloaded(video: video)
            }
        }
        return item
    }

    // MARK: - Playback

    private func startPlayback(completion: @escaping () -> Void, action: @escaping @MainActor () async -> Void) {
        guard playbackTask == nil else {
            completion()
            return
        }
        playbackTask = Task { [weak self] in
            defer {
                self?.playbackTask = nil
                completion()
            }
            await action()
            guard !Task.isCancelled, let self else { return }
            if let message = self.environment.playerService.state.errorMessage {
                let alert = CPAlertTemplate(titleVariants: [message], actions: [
                    CPAlertAction(title: String(localized: "OK"), style: .default) { [weak self] _ in
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    }
                ])
                self.interfaceController?.presentTemplate(alert, animated: true, completion: nil)
            } else {
                self.showNowPlaying()
            }
        }
    }

    private func showNowPlaying() {
        guard environment.playerService.state.currentVideo != nil,
              interfaceController?.topTemplate !== CPNowPlayingTemplate.shared else { return }
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { success, error in
            if !success {
                LoggingService.shared.error("CarPlay Now Playing failed: \(error?.localizedDescription ?? "Unknown error")", category: .player)
            }
        }
    }
}
#endif
