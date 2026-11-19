<div align="center">
  <img src="assets/yattee-logo.png" width="128" height="128" alt="Yattee logo" />
  <h1>Yattee</h1>
  <p>Privacy oriented video player for iOS, tvOS and macOS<br /></p>

[![AGPL v3](https://shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.en.html)
[![GitHub issues](https://img.shields.io/github/issues/yattee/yattee)](https://github.com/yattee/yattee/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/yattee/yattee)](https://github.com/yattee/yattee/pulls)


[![Discord](https://invidget.switchblade.xyz/pSnNKhZHEG)](https://yattee.stream/discord)
</div>

> **Yattee 2 is in the works!** A new version of the app is being built with a refreshed experience.
> It pairs with the new [Yattee Server](https://github.com/yattee/yattee-server) — a self-hosted backend powered by yt-dlp that supports 1000+ sites.
> Join the [TestFlight beta](https://yattee.stream/beta2) to try early builds, and check the new documentation site at [docs.yattee.stream](https://docs.yattee.stream) for guides, roadmap and changelog.

## Features
* Native user interface built with [SwiftUI](https://developer.apple.com/swiftui/) with customization settings
* Player queue and history
* Player component with custom controls, gestures and support for 4K playback
* Fullscreen, Picture in Picture and background audio playback
* [SponsorBlock](https://sponsor.ajay.app/), configurable categories to skip
* [Automation](https://docs.yattee.stream/docs/app/automation) with the `yattee://` URL scheme, x-callback-url, Shortcuts and Siri

## CarPlay development

The iOS app includes a CarPlay audio interface with Queue, Bookmarks, History, and
system Now Playing controls. Selecting a queue item removes only that item from
the queue; the remaining items keep their order. Bookmarks and History use local
saved data, and playback prefers downloads when available. Selecting content
turns on audio-only mode, which remains enabled until changed in the player.
Enable background playback on iPhone to keep listening when the phone locks.

Device builds require Apple approval for the
[CarPlay audio entitlement](https://developer.apple.com/carplay/) and a regenerated
provisioning profile containing `com.apple.developer.carplay-audio`.
`Yattee-iOS.entitlements` adds that capability only for iOS; macOS and tvOS use
their existing entitlements.

Builds with the iOS 26.5 SDK use the existing safe-area layout. The iOS 27.1
foldable layout APIs compile only when SwiftUI 8.1 or newer is available in the
SDK. Keep simulator signing enabled so Xcode embeds the simulated CarPlay
entitlement; no device provisioning profile is needed for this simulator build.

To build for an Apple Silicon iPhone simulator:

```sh
xcodebuild -scheme Yattee -configuration Debug -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=-
```

To test, open **I/O → External Displays → CarPlay** in Simulator. Verify a CarPlay launch before opening the iPhone window,
empty lists, selection from all three tabs, unavailable content, downloaded
playback offline, play/pause and skip controls, queue updates made on iPhone,
and disconnect/reconnect while playing. Test on a provisioned device and head
unit before release. This integration provides audio playback on CarPlay.

## License
Yattee and its components is shared on [AGPL v3](https://www.gnu.org/licenses/agpl-3.0.en.html) license.
