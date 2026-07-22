# App Store Connect metadata

Fill these fields in App Store Connect → your app → App Information / Prepare for Submission.

## App Information
- **Name** (30 char max): `IPTV Player` (check availability — this exact phrase is heavily used; consider a distinct name, e.g. "Streamline IPTV" or a made-up brand name)
- **Subtitle** (30 char max): `M3U Playlist Streaming`
- **Bundle ID**: `com.suriya.iptvplayer` (already set in the Xcode project)
- **Primary category**: Entertainment
- **Secondary category** (optional): Utilities
- **Content rights**: You will be asked "Does your app contain, show, or access third-party content?" — answer honestly. Since this app plays whatever stream URL the user supplies, answer **Yes**, and be ready to explain in reviewer notes that the app itself ships with no content and is a generic player (see risk note below).

## Description (4000 char max)
```
IPTV Player is a lightweight, no-frills client for watching your own IPTV subscription on iPhone.

• Add any M3U or M3U8 playlist URL to load your channel lineup
• Optional XMLTV program guide (EPG) support — see what's on now and next
• Browse channels by category or search by name
• Save favorites for quick access
• Built on AVKit for smooth, native HLS playback

IPTV Player does not provide, host, or bundle any channels, streams, or content of its own. You must supply your own playlist and EPG URLs from a source you are authorized to use. This app is a player only.
```

## Keywords (100 char max, comma-separated)
```
iptv,m3u,m3u8,playlist,streaming,player,live tv,epg,xmltv,channels
```

## Support URL / Marketing URL
You need a real, reachable URL for both (Marketing URL is optional but Support URL is required). Options:
- A GitHub repo README page for this project
- A simple one-page site
- Even a GitHub Pages page works

## Privacy Policy URL
Required. See `privacy-policy.html` in this folder — host it somewhere public (GitHub Pages is the easiest free option: push this repo to GitHub, enable Pages, and use the raw URL) and paste that link into App Store Connect.

## Age Rating questionnaire
Apple's age rating questionnaire asks about content types. Answer based on what the app *can* access, not a specific playlist:
- **Unrestricted Web Access**: Yes (the app can play streams from URLs the user provides — this alone often pushes the rating to 17+)
- Realistic Violence / Mature themes / etc.: No, unless you know your intended content includes it
- Expect the app to land at **17+** because of the unrestricted/user-provided content access — this is normal for generic media player apps and is not a rejection by itself.

## Copyright
`© 2026 [Your name or company]`

## App Review notes (paste into the "Notes" field for the reviewer)
```
This app is a generic IPTV/M3U playlist player, similar to VLC or IINA for mobile. It ships with
zero bundled content — the channel list and EPG are entirely populated from a playlist URL the
user enters themselves. For review purposes, you can test with any public M3U test playlist,
e.g. https://iptv-org.github.io/iptv/index.m3u (a free, community-maintained index of publicly
broadcast, non-DRM streams). The app performs no server-side aggregation, scraping, or content
hosting of its own.
```

---

## ⚠️ Read before submitting: content-rights risk

Apple's App Review Guidelines (sections 4.7 and 5.6, plus general IP-infringement policy) specifically
target apps whose primary function is playing arbitrary user-supplied stream URLs, because this exact
pattern is the standard distribution mechanism for pirated live-TV and sports streams. A reviewer may:
- Reject the app outright as facilitating infringement, even with no bundled content
- Ask you to prove you hold distribution rights to whatever you demo it with
- Request removal of "generic playlist" support entirely in favor of a single licensed source

This is a common, well-documented outcome for this app category — expect to possibly need an appeal,
a resubmission with a narrower scope (e.g. locking the app to one playlist source you have rights to),
or distributing via TestFlight/enterprise instead of the public App Store if rejected repeatedly.
