// Edge Function: daily birthday push via FCM HTTP v1 (configure FIREBASE_* secrets).
// Deploy: supabase functions deploy birthday-push
// Schedule: daily cron in Supabase dashboard.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const today = new Date()
  const mm = String(today.getMonth() + 1).padStart(2, '0')
  const dd = String(today.getDate()).padStart(2, '0')

  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('id, nome, aniversario')
    .not('aniversario', 'is', null)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  const birthdayIds = (profiles ?? [])
    .filter((p) => typeof p.aniversario === 'string' && p.aniversario.slice(5, 10) === `${mm}-${dd}`)
    .map((p) => ({ id: p.id as string, nome: p.nome as string }))

  let sent = 0
  for (const person of birthdayIds) {
    const { data: tokens } = await supabase
      .from('fcm_tokens')
      .select('token')
      .eq('profile_id', person.id)

    for (const row of tokens ?? []) {
      // Placeholder: integrate FCM HTTP v1 with service account.
      console.log(`Would push to ${row.token}: Parabéns, ${person.nome}!`)
      sent++
    }
  }

  return new Response(JSON.stringify({ ok: true, birthdays: birthdayIds.length, sent }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
