// Stripe → Gift Keeper: turns a family's plan on when they pay and off when they cancel.
// Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_... STRIPE_WEBHOOK_SECRET=whsec_... ULTRA_PAYMENT_LINK_ID=plink_...
// In Stripe, add a webhook to https://<project>.supabase.co/functions/v1/stripe-webhook for
// checkout.session.completed, customer.subscription.updated and customer.subscription.deleted.
import Stripe from 'npm:stripe@17';
import { createClient } from 'npm:@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async req => {
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(await req.text(), req.headers.get('stripe-signature')!,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!);
  } catch (e) {
    return new Response(`Bad signature: ${(e as Error).message}`, { status: 400 });
  }

  if (event.type === 'checkout.session.completed') {
    const s = event.data.object;
    // The app sends the family id as client_reference_id when it opens the Payment Link
    if (s.client_reference_id) {
      const { error } = await db.from('subscriptions').upsert({
        family_id: s.client_reference_id,
        tier: s.payment_link === Deno.env.get('ULTRA_PAYMENT_LINK_ID') ? 'ultra' : 'premium',
        status: 'active',
        since: new Date().toISOString().slice(0, 10),
        stripe_customer: typeof s.customer === 'string' ? s.customer : s.customer?.id,
        stripe_subscription: typeof s.subscription === 'string' ? s.subscription : s.subscription?.id,
      });
      if (error) return new Response(error.message, { status: 500 });   // Stripe retries
    }
  }

  if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
    const sub = event.data.object;
    const { error } = await db.from('subscriptions').update({ status: sub.status }).eq('stripe_subscription', sub.id);
    if (error) return new Response(error.message, { status: 500 });
  }

  return new Response('ok');
});
