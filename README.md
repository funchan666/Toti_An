# Toti for Android

Flutter Android application based on the LookMe iOS A-side. Original project media, fonts, sample profiles and editorial content are included. The B-side routing, WebSocket and remote WebView integration are excluded. The Android application ID remains `com.example.toti_an` as requested; configure the final ID and release signing before publishing.

## Implemented locally

The five main areas include short videos, discovery, example rooms, messages and profile. The app includes follows and sample incoming followers, comments and local safety tools; room filters, member lists, local microphone capture and example gift selection; local camera capture and call/broadcast previews; pending submissions; profile editing, daily coins, effects and backpack. English, Chinese, Spanish, Japanese and German translation dictionaries are imported from LookMe; strings not present in those dictionaries still appear in English.

Example profiles, videos and activity are bundled. Chat, reports, room activity and gifts are not delivered to other people or a moderation service. Microphone and camera previews are not broadcasts or connected calls. Submissions remain pending. These boundaries are shown in the app. Account data and attachments are kept on the device; deletion removes the app-managed pending attachments and state.

## Outstanding

This is not yet a complete or visually verified one-to-one port. LookMe's Apple sign-in and email flow, some room and activity details, speaker routing, complete translation coverage, and the exact original visual treatment still differ. No connected communication or moderation service exists in the A-side project to port. Toti's Google Play checkout is disabled until real product configuration, transaction verification, fulfillment and recovery exist. See `docs/GOOGLE_PLAY_PRODUCTS.md` for proposed IDs and reference prices.

The two bundled policies are drafts, and corresponding editable drafts have been created in Google Drive. The email is intentionally blank. Before release, establish a privacy contact and publish a suitable publicly accessible, non-editable policy URL; review and update the drafts to match the final features, services and data practices. The currently observed Google Play developer account was removed and cannot publish apps.

Before the UI refinement, an Android ARM64 debug APK was built and run on an Android 14 emulator. Login, video display, room entry and a local room message, and the daily coin reward were checked on the emulator; eight Flutter tests passed. The UI refinement has not yet been built or run. The app requires Android 7.0 (API 24) or later. A physical device, pixel-by-pixel comparison, release build, Google Play purchase, camera and microphone capture, and live services were not verified.
