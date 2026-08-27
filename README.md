<div align="center">
	<a href="https://github.com/CamilleScholtz/swmpc">
		<img src="https://raw.githubusercontent.com/CamilleScholtz/swmpc/refs/heads/main/Assets/Icon.webp" width="256" alt="swmpc">
	</a>
	<h3 align="center">swmpc</h3>
	<p align="center">
		An MPD client for macOS & iOS.
		<br />
		<a href="https://github.com/CamilleScholtz/swmpc/issues/new?template=bug_report.md">Report Bug</a>
		·
		<a href="https://github.com/CamilleScholtz/swmpc/issues/new?template=feature_request.md">Request Feature</a>
	</p>
	<p>
		<a href="https://apps.apple.com/app/swmpc/id6743818735" target="_blank"><img src="https://raw.githubusercontent.com/CamilleScholtz/swmpc/refs/heads/main/Assets/MacAppStore.svg" alt="Download on the Mac App Store"></a>&nbsp;&nbsp;<a href="https://apps.apple.com/nl/app/swmpc/id6743818735" target="_blank"><img src="https://raw.githubusercontent.com/CamilleScholtz/swmpc/refs/heads/main/Assets/AppStore.svg" alt="Download on the App Store"></a>
	</p>
</div>

- - -

Tired of janky MPD clients? Same.

`swmpc` is a fast, elegant MPD client built exclusively for macOS & iOS. A clean, native interface that feels right at home on your Apple devices.

#### What you get:

- **Fast library browsing**: Search artists, albums, and tracks instantly.
- **Sane queue management**: Add, remove, reorder. Drag and drop. No friction.
- **Full playlist support**: Create, edit, delete, and populate playlists without fighting the UI.
- **Favorites**: Quick access to tracks you actually listen to.
- **AI-powered smart fill**: Generate playlists or queue tracks by genre or mood.
- **Menu bar controls**: Skip, pause, adjust—without switching windows.
- **Widget support**: Control playback from your home or lock screen.
- **Open source**: Inspect it, fork it, contribute. It's your app too.
- **Universal purchase**: One price. Get it for both Mac and iPhone. Done.


## Screenshots

![App](https://raw.githubusercontent.com/CamilleScholtz/swmpc/refs/heads/main/Assets/App.webp)
![Popover](https://raw.githubusercontent.com/CamilleScholtz/swmpc/refs/heads/main/Assets/Popover.webp)


## Installation

The latest version of `swmpc` is available on the [App Store](https://apps.apple.com/app/swmpc/id6743818735). I've decided to make `swmpc` a paid app to help offset the many hours spent developing it, as well as expenses like the annual $100 Apple Developer License fee. Of course, you're also welcome to compile `swmpc` yourself from source.

`swmpc` is an universal app, meaning you only need to purchase it once to get it on both macOS and iOS.


## Requirements

- macOS 27.0 or later
- iOS 27.0 or later
- A server speaking MPD protocol 0.21 or later


## Server compatibility

`swmpc` speaks the MPD protocol, not one particular implementation. The floor is
protocol 0.21, which is where everything the app relies on arrived: filter
expressions, server-side sorting, `albumart`, and the plugin name in `outputs`.
Newer versions unlock `readpicture` (0.22), larger artwork chunks (0.22.4), and
sorting the queue and by song title (0.24).

| | Server | Protocol | Notes |
| --- | --- | --- | --- |
| ✅ | [MPD](https://www.musicpd.org) | 0.21+ | The reference implementation, and what `swmpc` is built against. |
| ✅ | MPD appliances such as [moOde](https://moodeaudio.org) and [Volumio](https://volumio.com) | varies | Real MPD underneath, so they behave like the above. They often pin an older build than MPD's current release. |
| ⚠️ | [OwnTone](https://owntone.github.io/owntone-server/) | 0.23 | Browsing, playback, queue and artwork work. Playlists are add-only: it implements none of `playlistclear`, `playlistdelete`, `playlistmove` or `rename`, so creating, renaming, reordering and removing from playlists (including un-favouriting) all fail. Forced rescans are unavailable too. Reported as [owntone-server#2034](https://github.com/owntone/owntone-server/issues/2034). |
| ❌ | [Mopidy](https://mopidy.com) with [Mopidy-MPD](https://github.com/mopidy/mopidy-mpd) | 0.19 | Below the floor, so `swmpc` refuses to connect. Mopidy-MPD targets the 0.19 protocol: no filter expressions, no `sort`, and no `albumart` or `readpicture`, so no album artwork ([mopidy-mpd#17](https://github.com/mopidy/mopidy-mpd/issues/17)). It also sends track numbers as `3/12` where MPD sends `3` ([mopidy-mpd#83](https://github.com/mopidy/mopidy-mpd/issues/83)). |

✅ supported &nbsp;·&nbsp; ⚠️ works with limitations &nbsp;·&nbsp; ❌ not supported

Compatibility is judged purely on the version a server announces. A server that
announces a version whose commands it does not actually implement is a bug worth
reporting to that project rather than working around here.


## Also by me

Check out my other project, [**Tripstitch**](https://tripstitch.app) — a smart trip planner that puts together your perfect itinerary.
