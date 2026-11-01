# Going live with Gift Keeper

The app works today with no setup (everything saved on the phone). These steps switch on
the real-world parts. Each one is independent.

## 1. Put it online (GitHub Pages, free)
    gh repo create peer85us/gift-keeper --public --source . --remote origin --push
    gh api -X POST repos/peer85us/gift-keeper/pages -f "source[branch]=master" -f "source[path]=/"
Site: https://peer85us.github.io/gift-keeper/  ·  App: …/gift-keeper/app.html

## 2. Accounts + family sync (Supabase, free tier)
1. Create a project at supabase.com.
2. SQL Editor → paste `supabase/schema.sql` → Run.
3. Authentication → Email: keep "Email" on. Authentication → Email Templates → "Magic Link":
   add `Your code: {{ .Token }}` so people can type the code (needed inside the installed phone app).
4. Authentication → URL Configuration: Site URL = https://peer85us.github.io/gift-keeper/app.html
5. Project Settings → API: copy the Project URL and the anon public key into `app.html`
   (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
6. Before real launch: Authentication → SMTP — connect a real email sender (Resend, Postmark…);
   Supabase's built-in sender only allows a few emails an hour.

## 3. Real payments by card, inside the app (Stripe)
Needs step 2 (accounts) first. You need a Stripe account (stripe.com, an adult with a bank account).
1. Stripe → Developers → API keys: copy the **publishable key** (pk_...) into `app.html` (`STRIPE_KEY`).
2. Deploy the two server functions (Supabase CLI: `brew install supabase/tap/supabase`, then `supabase login` and `supabase link`):
       supabase functions deploy checkout
       supabase functions deploy stripe-webhook --no-verify-jwt
       supabase secrets set STRIPE_SECRET_KEY=sk_live_... STRIPE_WEBHOOK_SECRET=whsec_... APP_URL=https://peer85us.github.io/gift-keeper/app.html
3. Stripe → Developers → Webhooks → add endpoint
   `https://<project>.supabase.co/functions/v1/stripe-webhook` with events
   checkout.session.completed, customer.subscription.updated, customer.subscription.deleted
   (that page shows the whsec_ secret for step 2).
4. Stripe → Settings → Billing → Customer portal: turn on, copy the login link into `BILLING_PORTAL`
   so people can cancel plans.
5. Try it in **test mode** first (pk_test_/sk_test_ keys, card 4242 4242 4242 4242, any future date, any CVC),
   then switch to the live keys.

What people can buy: Keeper Coins packs ($0.99 / $4.99 / $9.99 / $19.99, one-time) and the
Premium ($9.99) and Ultra ($19.99) monthly plans. Prices are set in `supabase/functions/checkout/index.ts`.
Coins are kept on the server, so they can't be faked.

Simpler option without the server functions: make Stripe Payment Links and paste them into
`PAYMENT_LINK`, `PAYMENT_LINK_ULTRA` and the `link` fields of `COIN_PACKS` (these open Stripe's page
instead of a form inside the app).

**App stores:** Apple and Google require their own in-app purchase system (they keep 15–30%)
for coins and plans sold inside an App Store / Play Store app. Card payments are fine on the website
and the installed web app.

## 4. Test with real families
Share the link with 5–10 families. Feedback goes to the GitHub Issues page
(Settings → Send feedback). Watch where people get stuck.

## Later: App Store / Google Play
Wrap the web app with Capacitor once people are using it. Needs an Apple developer account
($99/year) and a Google Play account ($25 once).
