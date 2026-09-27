# Store Presence Refresh — Issues #180, #181, #182

Prepared on 27 September 2026 for Android **1.14.3+86**, based on the delivered
1.14.2 source. The release owner confirmed that Google Play currently serves
Android **1.14.1 in closed testing**. **Publish this listing and its screenshots together with the
matching Android release, not ahead of that release.** Store publication and
the production-signing/upload steps remain release-owner actions.

**Closed testing and #182:** the repository and public project homepage both use
`com.codefrog.terramanager`. The release owner confirmed that the listing is
not publicly accessible because the app is in closed testing. Its anonymous
HTTP 404 therefore does not establish that the destination is wrong. The link
keeps the existing Android application ID. Android dispatch to Google Play and
the Chrome fallback were verified on an Android 12 emulator. Access to the
private listing itself could not be verified anonymously; a tester must be
eligible for the closed test through Google Play. Confirm that access using the
signed candidate and an eligible tester account before publication. This is
handled by the external Store and adds no TerraManager account requirement.

## Ready-to-review listing

`listing/de-DE/` and `listing/en-US/` each contain separate UTF-8 title,
short-description and full-description files. Paste their contents, without
the final file newline, into the corresponding Play Console language fields.

| Field | German | English | Current limit |
| --- | ---: | ---: | ---: |
| Title | 12 | 12 | 30 |
| Short description | 70 | 73 | 80 |
| Full description | 3,146 | 2,848 | 4,000 |

The description explains local Boxes and Animals, feeding history, in-app
reminders, QR selection/opening/feeding/export, cropping and galleries, portable
backups and local storage. It distinguishes the operator-hosted Shared Care
browser from the Android collection and explicitly rules out automatic sync.
It includes the existing localized public guide and project links. No claim of
push notifications, developer cloud hosting or automatic backup is made.

The feature claims were checked against the delivered standalone code:

| Claim | Implementation reference |
| --- | --- |
| Box/Animal management and archive | `lib/features/boxes/`, `lib/features/animals/` |
| Feeding history and reminders inside the app | `lib/features/feedings/` |
| QR Box lookup, creation selection, rehouse, Feeding Mode | Box/Animal scanner pages and `feeding_scanner_page.dart` |
| Selected QR export as PNG/ZIP/PDF | Settings and `lib/features/settings/application/` |
| Crop, primary picture and ordered fullscreen gallery | `lib/features/media/` |
| Portable `.tmbackup` export/restore | `lib/features/backup/` |
| Local Android collection, no developer telemetry | `PRIVACY.md`, Android main manifest |
| Separate Shared Care collection with manual backup transfer | Existing browser-link explanation and Shared Care deployment documentation |

## Screenshot set

Upload the eight files in `screenshots/de/` for German and the corresponding
eight files in `screenshots/en/` for English. Numbered filenames define the
intended order. `alt-text.json` supplies localized accessibility descriptions.
`review-contact-sheet.png` shows both languages side by side as rows; it is a
review aid and is not a Store screenshot.
Open `review.html` locally to read each complete description next to its eight
screenshots. This review page works offline and has no publication controls.

1. Boxes overview with demonstration enclosures and pictures.
2. Animal details with scientific name, assigned Box and care information.
3. Feeding history with demonstration dates and notes.
4. Animals overview with due/upcoming feeding information.
5. Box details at the actual QR-code section.
6. New Animal form at the Box selector and QR scanner button.
7. Animal gallery with primary-picture selection and demonstration images.
8. Settings at portable backup creation/restoration and QR exports.

The app UI is captured from the actual standalone Flutter pages and theme,
including the real shell and navigation. It is not a reconstruction or UI
mockup. A short localized caption is added above the intact capture. The header
uses the existing project green palette; terminology follows the app. Every
frame is labelled as demonstration data. The dataset and procedural SVG/PNG
illustrations were created specifically for these assets and do not contain a
user's collection, photographs, account details or private notes.

Phone exports are **1080 × 1920 RGB PNGs**, without alpha. The capture itself is
rendered at 1080 × 1614 pixels from a 360 × 538 logical viewport at scale 3;
the composition does not enlarge, stretch or redraw it. Caption space occupies
14.1% of the frame. These are phone assets, not claims of tablet or TV layouts.

## Editable and reproducible sources

- `source/screenshots.json`: captions, alt text, order, colors, dimensions and
  release association.
- `source/captures/de/` and `source/captures/en/`: unmodified UI PNG captures.
- `source/templates/de/` and `source/templates/en/`: independent SVG frames with
  embedded captures and editable caption text. Use Noto Sans, already present
  in the repository, when opening them in a vector editor.
- `source/demo-images/`: original editable SVG illustration geometry and PNGs.
- `source/demo-collection-de.tmbackup` and `source/demo-collection-en.tmbackup`:
  portable examples for refreshing screenshots on an isolated installation.
- `source/device-demo.sqlite`: synthetic fixture used only for the temporary
  debug emulator. Do not install it over an existing user database.
- `tool/store_presence/capture_screenshots_test.dart`: creates the synthetic
  collection and captures production widgets in both languages.
- `tool/store_presence/render_assets.py`: regenerates demonstration images,
  composes screenshots/SVG frames and checks text limits. Requires Python 3
  and Pillow; it adds no runtime dependency to TerraManager.

To refresh the assets from the repository root:

```text
python tool/store_presence/render_assets.py --demo-only
flutter pub get
flutter gen-l10n
# Set STORE_FLUTTER_ROOT to the directory containing your Flutter SDK's bin/.
flutter test --no-pub tool/store_presence/capture_screenshots_test.dart
python tool/store_presence/render_assets.py
```

The capture tool loads Roboto from the Flutter SDK so it does not use the test
runner's Ahem placeholder font. It writes only the demonstration asset directory.
It is run explicitly and is not part of the normal test suite. Gallery dates
and feeding entries are demonstration values. Relative reminders in the real
app shell follow the capture date; refresh the examples when the release changes.

The illustrations and tool sources are original repository assets under the
project's GPL-3.0-or-later license. No third-party photo license or real-user
image is needed. Existing Noto Sans and SDK Roboto retain their existing licenses.

## Play requirements checked on 27 September 2026

The current Google guidance allows JPEG or 24-bit PNG without alpha, 320–3840 px
per side, a maximum 2:1 ratio, and up to eight screenshots per device type. For
app recommendation formats it calls for at least four 1080 × 1920 portrait or
1920 × 1080 landscape screenshots. Captures should show actual app content;
additional taglines should occupy at most 20%. This set uses eight portrait
phone PNGs per language and avoids install calls to action, rankings and store
badges. Title/short/full limits are 30/80/4,000 characters.

Sources: [Preview asset requirements](https://support.google.com/googleplay/android-developer/answer/1078870?hl=en),
[Create a store listing](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en),
[Listing best practices](https://support.google.com/googleplay/android-developer/answer/13393723?hl=en).
Recheck these official pages in Play Console at upload time. The existing app
icon and feature graphic are outside this screenshot-replacement issue.

## Voluntary Settings link

The Android standalone Settings page includes **TerraManager bewerten / Rate
TerraManager** beside the existing project and guide links. An explicit tap
opens `market://details?id=com.codefrog.terramanager` in `com.android.vending`.
If that handler is unavailable or blocked, Android tries the public HTTPS
listing in the browser:

`https://play.google.com/store/apps/details?id=com.codefrog.terramanager`

If neither destination can be opened, localized feedback is shown and the
action becomes available again. While opening, repeated taps are disabled.
There is no rating prompt, review-submission API, telemetry, account requirement,
new device permission or new dependency. The app never opens this link on its
own. Standalone Web and Shared Care do not gain an Android Store action.

## Review and publication handoff

Verification: 1,064 ordinary tests passed with one pre-existing skip; seven new
rating-link cases cover labels, explicit tap, no payload, pending taps, failure
feedback, platform visibility and Settings integration. Both explicit bilingual
screenshot-generation cases passed. Static analysis has no issues and the
Android debug build succeeded. Real Android intent records show the Google Play
handler and, with that package temporarily disabled, Chrome. The package was
re-enabled afterwards. A physical phone, signed production candidate and Store
publication have not been tested or performed here.

Review the contact sheet together with both full descriptions. Confirm that
the Android version about to be published contains the shown workflows, then
upload the matching language assets and alt text. The captions and description
share one workflow order and make no automatic-sync claim.

Before production publication, the release owner should install the signed
candidate on a physical phone and confirm the voluntary Settings link. Check
the matching listing with an eligible tester account while it is in closed
testing, and check the browser fallback when Google Play is not available.
Preserve the source assets in the repository for later updates.
Do not submit a review as part of testing. Store publication is intentionally
left to the release owner.
