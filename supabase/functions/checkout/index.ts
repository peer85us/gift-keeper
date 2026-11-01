// Starts a card payment inside the app (Stripe Embedded Checkout) for a coin pack or a plan.
// Prices live here on the server, so nobody can change what they pay from their phone.
// Deploy:  supabase functions deploy checkout
// Secrets: STRIPE_SECRET_KEY (shared with stripe-webhook), APP_URL=https://peer85us.github.io/gift-keeper/app.html
import Stripe from 'npm:stripe@17';
import { createClient } from 'npm:@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
// Keep in step with COIN_PACKS and the plan prices in app.html
const PACKS: Record<string, { coins: number; cents: number }> = {
  c100: { coins: 100, cents: 99 }, c500: { coins: 550, cents: 499 },
  c1000: { coins: 1200, cents: 999 }, c2000: { coins: 2600, cents: 1999 },
};
const PLANS: Record<string, { name: string; cents: number }> = {
  premium: { name: 'Gift Keeper Premium', cents: 999 }, ultra: { name: 'Gift Keeper Ultra', cents: 1999 },
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  // Who is asking: the signed-in user's own token, so RLS checks they belong to the family
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
  const { data: { user } } = await db.auth.getUser();
  if (!user) return json({ error: 'Please sign in' }, 401);

  const { kind, family, member, pack, tier } = await req.json();
  const { data: fam } = await db.from('families').select('id').eq('id', family).maybeSingle();
  if (!fam) return json({ error: 'Not in this family' }, 403);

  const base = {
    ui_mode: 'embedded' as const,
    return_url: `${Deno.env.get('APP_URL')}?paid={CHECKOUT_SESSION_ID}`,
    redirect_on_completion: 'if_required' as const,
    customer_email: user.email,
  };
  let session;
  if (kind === 'coins' && PACKS[pack]) {
    const p = PACKS[pack];
    session = await stripe.checkout.sessions.create({
      ...base, mode: 'payment',
      line_items: [{ quantity: 1, price_data: { currency: 'usd', unit_amount: p.cents,
        product_data: { name: `${p.coins.toLocaleString()} Keeper Coins` } } }],
      metadata: { kind: 'coins', family, member: String(member), pack, coins: String(p.coins) },
    });
  } else if (kind === 'plan' && PLANS[tier]) {
    const p = PLANS[tier];
    session = await stripe.checkout.sessions.create({
      ...base, mode: 'subscription',
      line_items: [{ quantity: 1, price_data: { currency: 'usd', unit_amount: p.cents, recurring: { interval: 'month' },
        product_data: { name: p.name } } }],
      metadata: { kind: 'plan', family, tier },
      subscription_data: { metadata: { kind: 'plan', family, tier } },
    });
  } else return json({ error: 'Unknown item' }, 400);

  return json({ clientSecret: session.client_secret });
});
