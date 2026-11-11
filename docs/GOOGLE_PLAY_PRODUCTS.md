# Toti Google Play consumable product plan

The user reports that the one-time products have been configured and enabled in Play Console; their exact current settings have not been independently checked because the accessible developer account is unavailable. The Android application ID is `com.toticonnect.meetcommuinity`, matching the ID provided for Google Play. Google Play product IDs cannot be changed or reused after creation. Prices below are the corresponding LookMe iOS reference values in USD, not verified Google Play prices; Play Console defines the actual prices and local taxes/currencies.

| Product ID | Coins | LookMe reference price (USD) |
| --- | ---: | ---: |
| `toti_coins_500.` | 500 | 0.99 |
| `toti_coins_1050` | 1,050 | 1.99 |
| `toti_coins_1650` | 1,650 | 2.99 |
| `toti_coins_2900` | 2,900 | 4.99 |
| `toti_coins_6000` | 6,000 | 9.99 |
| `toti_coins_12500` | 12,500 | 19.99 |
| `toti_coins_33000` | 33,000 | 49.99 |
| `toti_coins_72000` | 72,000 | 99.99 |
| `toti_coins_115000` | 115,000 | 149.99 |

The app displays the coin packs with labeled USD reference prices. It checks the selected ID against the Play catalog on request and replaces the reference price with the Play-returned price when available. Checkout is not yet implemented: creating a product in Play Console does not implement the purchase flow or credit coins. Do not issue coins based only on an unverified client callback.

The server-side Google API helper at `supabase/functions/_shared/google_play.ts` is preparation only. It has not been deployed or connected to an endpoint, wallet, or app purchase flow. A completed integration still needs authenticated user-to-purchase binding, an atomic token-unique ledger and persistent wallet, safe migration of existing device balances, recovery and consumption retries, refund/void reconciliation, server credentials, app purchase handling, and end-to-end verification. A token already consumed at Google must only be accepted as a retry of an existing matching ledger entry, never as a new credit.

The existing balance, daily rewards, and spending are device-local; example gifts are explicitly not delivered to other people. They must not be represented as server-backed paid features until their behavior and wallet migration are implemented. Keep checkout disabled until the complete path is ready.

The 500-coin product ID ends in a period because the original ID was created and deleted in Play Console and cannot be reused. The source now uses the replacement; already-uploaded builds retain the old ID until a new build is submitted.

The currently accessible Play developer account was removed. The user reports submitting Toti from another account but cannot currently switch to it. Server-side verification requires a Google Cloud project with the Google Play Developer API enabled and a service account authorized for this app in that active Play Console account. Store the service account JSON only as the `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` Supabase Edge Function secret, never in the repository or mobile app. The Play Console permissions required by Google's setup guide include viewing financial data and managing orders. Confirm the live product IDs and price settings when access is restored.

Open testing can charge real money. Add test accounts as Google Play license testers and select Google's test payment methods for no-charge purchase testing. A new app bundle with a higher version code must be uploaded for any app-side payment changes; the already-submitted bundle cannot be modified in place.

References: https://support.google.com/googleplay/android-developer/answer/1153481 and https://developer.android.com/google/play/billing/backend
