# App Store submission checklist

Everything code/asset-related is done and lives in this repo:
- App icon: `IPTVPlayer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Screenshots: `AppStore/screenshot_setup.png`, `AppStore/screenshot_channels.png`
- Metadata to paste into App Store Connect: `AppStore/metadata.md`
- Privacy policy page to host: `AppStore/privacy-policy.html`

## Done
1. ✅ Apple Developer Program enrollment (Team ID `GJMQYG8M85`, Individual)
2. ✅ Signed into Xcode with that account
3. ✅ Code signing configured (`project.yml` sets `CODE_SIGN_STYLE: Automatic` and
   `DEVELOPMENT_TEAM: GJMQYG8M85`) — verified working end to end:
   - `xcodebuild archive` succeeds
   - `xcodebuild -exportArchive` produces a correctly signed `.ipa`
     (`Apple Distribution: suriya narayanan venkatesan (GJMQYG8M85)`), currently at
     `build/export/IPTVPlayer.ipa`

## Still needed (requires your App Store Connect login)

### 4. Host the privacy policy
- Push this project (or just the `AppStore` folder) to a GitHub repo
- Enable GitHub Pages, or use any static host
- Note the public URL to `privacy-policy.html` — you'll paste it into App Store Connect

### 5. Create the app record in App Store Connect
- https://appstoreconnect.apple.com → My Apps → **+** → New App
- Platform: iOS
- Name, primary language, bundle ID `com.suriya.iptvplayer`, SKU (any unique string, e.g. `iptvplayer001`)
- Fill in the fields from `AppStore/metadata.md`
- Upload `AppIcon-1024.png` and the screenshots where prompted
- Paste your hosted privacy policy URL
- Complete the age rating questionnaire (see notes in `metadata.md`)

This is the one remaining hard blocker — I attempted the upload and got
`missingApp(bundleId: "com.suriya.iptvplayer")`, confirming App Store Connect has no app record
for this bundle ID yet. Everything else (signing, archiving, exporting) is already proven to work.

### 6. Upload the build
Once the app record exists, either:
- **Command line** (fastest — re-run exactly what already worked):
  ```
  cd /Users/suriya/IdeaProjects/IPTVPlayer
  xcodebuild archive -project IPTVPlayer.xcodeproj -scheme IPTVPlayer \
    -archivePath build/IPTVPlayer.xcarchive -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates
  xcodebuild -exportArchive -archivePath build/IPTVPlayer.xcarchive \
    -exportPath build/export -exportOptionsPlist build/ExportOptions.plist \
    -allowProvisioningUpdates
  ```
  Add `<key>destination</key><string>upload</string>` back into `build/ExportOptions.plist`
  before the second command to upload directly instead of just exporting locally.
- **Xcode GUI**: open `IPTVPlayer.xcodeproj`, Product → Archive, then in the Organizer window
  click **Distribute App** → **App Store Connect** → **Upload**.

Processing in App Store Connect typically takes 15–60 minutes before the build is selectable.

## 6. Finish the App Store Connect listing
- Attach the processed build to the version
- Fill in "What's New" (can be generic for v1, e.g. "Initial release")
- Add the App Review notes from `metadata.md`
- Set pricing (Free, or a price tier) and availability

## 7. Submit for review
- Click **Add for Review** → **Submit to App Review**
- Typical review time: 24–48 hours, but varies

## About the likely outcome
Read the risk note at the bottom of `metadata.md` before submitting. Generic M3U/IPTV player apps
are frequently rejected under guidelines 4.7 / 5.6 (facilitating access to unlicensed content) even
with zero bundled content, because the app *shape* is what pirate IPTV clients look like. If that
happens:
- You'll get a message in the Resolution Center from the reviewer citing a specific guideline
- You can reply with clarification (e.g. link to `AppStore/metadata.md`'s framing) and request a
  second look, or
- Consider narrowing the app to one playlist source you can prove you have rights to, or
- Distribute via TestFlight (up to 10,000 testers, no App Review content-rights scrutiny in the same
  way) instead of the public App Store.
