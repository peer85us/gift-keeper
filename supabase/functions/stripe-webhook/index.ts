// Stripe → Gift Keeper: adds coins when a pack is paid for, and turns a family's plan on and off.
// Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_... STRIPE_WEBHOOK_SECRET=whsec_...
// In Stripe, add a webhook to https://<project>.supabase.co/functions/v1/stripe-webhook for
// checkout.session.completed, customer.subscription.updated and customer.subscription.deleted.
import Stripe from 'npm:stripe@17';
import { createClient } from 'npm:@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const id = (x: string | { id: string } | null) => typeof x === 'string' ? x : x?.id;

Deno.serve(async req => {
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(await req.text(), req.headers.get('stripe-signature')!,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!);
  } catch (e) {
    return new Response(`Bad signature: ${(e as Error).message}`, { status: 400 });
  }

  let error = null;
  if (event.type === 'checkout.session.completed') {
    const s = event.data.object, m = s.metadata ?? {};
    if (m.kind === 'coins' && s.payment_status === 'paid') {
      // ref is unique, so a retried webhook can't add the coins twice
      ({ error } = await db.from('coin_ledger').upsert({ family_id: m.family, member: m.member,
        delta: Number(m.coins), reason: 'buy:' + m.pack, ref: s.id }, { onConflict: 'ref', ignoreDuplicates: true }));
    }
    if (m.kind === 'plan') {
      ({ error } = await db.from('subscriptions').upsert({ family_id: m.family, tier: m.tier, status: 'active',
        since: new Date().toISOString().slice(0, 10), stripe_customer: id(s.customer as never), stripe_subscription: id(s.subscription as never) }));
    }
  }
  if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
    const sub = event.data.object;
    ({ error } = await db.from('subscriptions').update({ status: sub.status }).eq('stripe_subscription', sub.id));
  }
  if (error) return new Response(error.message, { status: 500 });   // Stripe retries
  return new Response('ok');
});
