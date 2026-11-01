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

## 3. Real payments (Stripe)
1. Stripe → Products: "Gift Keeper Premium" $9.99/month and "Gift Keeper Ultra" $19.99/month.
2. Create a Payment Link for each. After payment → redirect to
   `…/app.html?premium=success` (Premium) and `…/app.html?premium=success&tier=ultra` (Ultra).
3. Paste the links into `app.html` (`PAYMENT_LINK`, `PAYMENT_LINK_ULTRA`).
4. Settings → Billing → Customer portal → turn on, copy the login link into `BILLING_PORTAL`.
5. Deploy the webhook (needs the Supabase CLI):
       supabase functions deploy stripe-webhook --no-verify-jwt
       supabase secrets set STRIPE_SECRET_KEY=sk_live_... STRIPE_WEBHOOK_SECRET=whsec_... ULTRA_PAYMENT_LINK_ID=plink_...
   In Stripe → Developers → Webhooks, add
   `https://<project>.supabase.co/functions/v1/stripe-webhook` with events
   checkout.session.completed, customer.subscription.updated, customer.subscription.deleted.
With accounts on, people must sign in before paying, and the plan is checked on the server.

## 4. Test with real families
Share the link with 5–10 families. Feedback goes to the GitHub Issues page
(Settings → Send feedback). Watch where people get stuck.

## Later: App Store / Google Play
Wrap the web app with Capacitor once people are using it. Needs an Apple developer account
($99/year) and a Google Play account ($25 once).
