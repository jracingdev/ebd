// Edge Function: push diário de aniversário via FCM HTTP v1.
// Deploy: supabase functions deploy birthday-push
// Secrets (opcionais — sem eles a função roda em modo dry-run):
//   FIREBASE_PROJECT_ID
//   FIREBASE_CLIENT_EMAIL
//   FIREBASE_PRIVATE_KEY  (PEM com \n escapados)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

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
    return json({ error: error.message }, 500)
  }

  const birthdayIds = (profiles ?? [])
    .filter(
      (p) =>
        typeof p.aniversario === 'string' &&
        p.aniversario.slice(5, 10) === `${mm}-${dd}`,
    )
    .map((p) => ({ id: p.id as string, nome: p.nome as string }))

  const fcmReady = Boolean(
    Deno.env.get('FIREBASE_PROJECT_ID') &&
      Deno.env.get('FIREBASE_CLIENT_EMAIL') &&
      Deno.env.get('FIREBASE_PRIVATE_KEY'),
  )

  let sent = 0
  let skipped = 0
  const errors: string[] = []

  let accessToken: string | null = null
  if (fcmReady) {
    try {
      accessToken = await getAccessToken()
    } catch (e) {
      return json({
        ok: false,
        error: `Falha ao obter token FCM: ${e}`,
        birthdays: birthdayIds.length,
        fcmConfigured: true,
      }, 500)
    }
  }

  for (const person of birthdayIds) {
    const { data: tokens } = await supabase
      .from('fcm_tokens')
      .select('token')
      .eq('profile_id', person.id)

    for (const row of tokens ?? []) {
      const token = row.token as string
      const title = 'Feliz aniversário!'
      const body = `Parabéns, ${person.nome}! Deus abençoe seu dia 🎉`

      if (!fcmReady || !accessToken) {
        // Dry-run explícito (sem secrets Firebase).
        console.log(`[birthday-push dry-run] Would push to ${token}: ${body}`)
        skipped++
        continue
      }

      try {
        await sendFcmHttpV1(accessToken, token, title, body)
        sent++
      } catch (e) {
        errors.push(`${person.nome}: ${e}`)
        console.error('FCM send failed', e)
      }
    }
  }

  return json({
    ok: true,
    birthdays: birthdayIds.length,
    sent,
    skipped,
    fcmConfigured: fcmReady,
    mode: fcmReady ? 'fcm_http_v1' : 'dry_run',
    errors: errors.slice(0, 10),
  })
})

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}

async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!
  const privateKeyPem = Deno.env.get('FIREBASE_PRIVATE_KEY')!.replace(
    /\\n/g,
    '\n',
  )
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 60),
    },
    key,
  )

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const data = await res.json()
  if (!res.ok || !data.access_token) {
    throw new Error(data.error_description ?? data.error ?? 'token failed')
  }
  return data.access_token as string
}

async function sendFcmHttpV1(
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
) {
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          android: { priority: 'high' },
        },
      }),
    },
  )
  if (!res.ok) {
    const text = await res.text()
    throw new Error(text.slice(0, 200))
  }
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}
