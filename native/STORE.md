# Gift Keeper on the App Store and Google Play

The iPhone and Android apps live in this folder (Capacitor). They run the same `app.html` as the website.
Inside the apps there is **no buying** (no coin packs, no Premium/Ultra checkout): Apple and Google require their own
in-app billing for digital goods, and Stripe would get the apps rejected. Coins are earned for free in the apps.
Add store billing later (RevenueCat makes this easiest) once both developer accounts exist.

App ID (both stores, permanent): `io.github.peer85us.giftkeeper`

## Every time app.html changes
```sh
cd ~/gift-keeper/native && ./build-web.sh
```
Then build a new version in Xcode / Android Studio (bump the version number first).

---

## 1. Things only you can do
1. **Apple Developer Program** — developer.apple.com/programs → Enroll ($99/year). Use your Apple ID with two-factor on.
2. **Google Play Console** — play.google.com/console → Create account → Personal ($25 once). ID check takes 1–3 days.
3. Install **Xcode** (Mac App Store) and **Android Studio** (developer.android.com/studio).

## 2. iPhone (App Store)
1. `cd ~/gift-keeper/native && npx cap open ios` — opens Xcode.
2. Click **App** (left) → **Signing & Capabilities** → Team: pick your developer account.
3. Plug in your iPhone, pick it at the top, press ▶ to try it.
4. appstoreconnect.apple.com → My Apps → **+ New App**: name *Gift Keeper*, bundle ID `io.github.peer85us.giftkeeper`, SKU `giftkeeper`.
5. In Xcode: top bar device → **Any iOS Device** → Product → **Archive** → Distribute App → App Store Connect → Upload.
6. In App Store Connect fill in the listing below, add screenshots (6.9" iPhone: 1320×2868), pick the build, **Submit for Review**.

## 3. Android (Google Play)
1. `cd ~/gift-keeper/native && npx cap open android` — opens Android Studio (let it finish "Gradle sync").
2. Try it: plug in an Android phone (USB debugging on) or start an emulator → ▶ Run.
3. Build → **Generate Signed App Bundle** → Android App Bundle → create a new keystore.
   **Back up the keystore file and passwords** (not in GitHub) — losing them means you can never update the app.
4. Play Console → Create app → upload the `.aab` under **Testing → Closed testing**.
5. New personal accounts must run a closed test with **12+ testers for 14 days** before going to Production.
   Friends and family with Android phones work — add their Gmail addresses as testers.
6. Fill in the listing, Data safety and Content rating (answers below) → apply for Production.

---

## Store listing

**Name:** Gift Keeper
**Subtitle (Apple, 30 chars):** Every family gift card, saved
**Short description (Google, 80 chars):** All your family's gift cards in one place. Never let a balance expire again.

**Description:**
Never lose a gift card again.

Gift Keeper keeps every gift card for the whole family in one place — balances, card numbers, PINs and expiration dates — so the money on them actually gets spent.

• Add a card in seconds: scan it with your camera or type it in
• See every balance at a glance, and update it after you shop
• Get a reminder before a card expires, so you never lose money
• Show the barcode right at the register
• Family profiles for parents and kids, each with their own cards
• Kids' savings goals, achievements and fun card styles
• Card numbers and PINs are encrypted on your phone

Earn Keeper Coins for free every day — by building a streak, adding cards and unlocking achievements — and spend them on card styles, stickers, pets and app colors.

No ads. We never sell your information.

**Keywords (Apple, 100 chars):** gift card,balance,wallet,tracker,family,expiration,reminder,store card,barcode,kids,savings
**Category:** Finance (Apple: primary Finance, secondary Lifestyle)
**Privacy policy URL:** https://peer85us.github.io/gift-keeper/privacy.html
**Support / marketing URL:** https://peer85us.github.io/gift-keeper/
**Price:** Free

## Apple — App Privacy answers
- Data collected: **None linked to tracking.** Tracking: **No.**
- Without an account nothing leaves the phone. If accounts (Supabase) are switched on later, update this to:
  Contact Info → Email (app functionality, linked to user, not tracking); User Content → Other (app functionality, linked, not tracking).
- Age rating: no objectionable content → **4+**. Do **not** put it in the Kids category (it's for parents).
- Encryption: already declared in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).

## Google — Data safety answers
- Does the app collect or share user data? **No** (while accounts are off — everything stays on the device).
  When accounts are on: collects Email address and "Other user-generated content", for App functionality and Account management, encrypted in transit, users can request deletion (Settings → Delete account).
- Target audience: **18 and over** (parents). Not designed for children; kids use it under a parent's profile.
- Content rating questionnaire: Utility/Productivity, answer No to everything → Everyone.
- Ads: **No.**

## Review notes (paste into both stores)
Gift Keeper stores gift card balances that the user types in or scans. No account is needed — everything is saved on the device.
To try the family features, open the profile button at the top right and add a family member.
Keeper Coins are earned free in the app (daily bonus, streaks, achievements) and can't be bought or cashed out in this version.

## Known review risks
- **Apple 4.2 (minimum functionality):** the app wraps the web app. It has camera scanning, real expiry notifications and works
  fully offline, which usually passes. If rejected, add Face ID unlock and home-screen widgets.
- **Premium screens:** in the apps they say "Upgrades aren't available in the app yet". If a reviewer objects, hide
  the Premium badges in the apps entirely (`IS_APP` in app.html).
