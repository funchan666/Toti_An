# LiveKit integration status

Toti's real-user voice rooms, live broadcasts, and one-to-one voice/video calls use LiveKit Cloud. Authenticated session access and call invitations are controlled by Supabase RPCs and the `rtc-token` Edge Function. LiveKit credentials are kept in Supabase function secrets and must never be shipped in the app.

The `toti_rtc_sessions` migration and `rtc-token` function have been deployed to the Toti Supabase project. The app source contains the Android integration, including microphone and camera permission requests. Real accounts must mutually follow each other to call. Existing editorial profiles and prerecorded content remain available but are not real RTC participants.

This is an implementation and deployment record, not a runtime acceptance result. The Android app has not been compiled or exercised for this change. Two real accounts on separate devices are still needed to verify call invitation, accept/decline, audio and video in both directions, live hosting/viewing, voice rooms, messaging, permission denial, reconnection, and ending a session. Incoming calls are currently presented only while the app is open; background/terminated-app notifications are not implemented. Real-session gift transfers and Bluetooth headset behavior have not been implemented or validated.

The LiveKit project uses its existing free allocation; usage and availability should be monitored. The public privacy policy was updated to describe the audio/video service. Supabase's security advisor also reported leaked-password protection disabled; this is independent of RTC.
