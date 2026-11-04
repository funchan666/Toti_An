# Toti Google Play consumable product plan

These IDs are proposed, not registered. Create them only for the intended Toti application after its final Android application ID is established. Google Play product IDs cannot be changed or reused after creation. Prices below are the corresponding LookMe iOS reference values in USD, not active Google Play prices; Play Console must define the actual prices and local taxes/currencies.

| Product ID | Coins | LookMe reference price (USD) |
| --- | ---: | ---: |
| `toti_coins_500` | 500 | 0.99 |
| `toti_coins_1050` | 1,050 | 1.99 |
| `toti_coins_1650` | 1,650 | 2.99 |
| `toti_coins_2900` | 2,900 | 4.99 |
| `toti_coins_6000` | 6,000 | 9.99 |
| `toti_coins_12500` | 12,500 | 19.99 |
| `toti_coins_33000` | 33,000 | 49.99 |
| `toti_coins_72000` | 72,000 | 99.99 |
| `toti_coins_115000` | 115,000 | 149.99 |

The app queries the Play catalog for these IDs and displays only Play-returned prices. Checkout deliberately remains unavailable: a secure verification and fulfillment/recovery mechanism, Play Console products, and real-device testing are still required. Do not issue coins based only on an unverified client callback. Google Play recommends a secure backend for verification, transaction uniqueness, consumption and handling voided purchases. This project has no such service and B-side integration was excluded.

The currently observed Play developer account was removed and cannot publish new applications. Do not treat these IDs as created or the payment flow as ready.

References: https://support.google.com/googleplay/android-developer/answer/1153481 and https://developer.android.com/google/play/billing/backend
