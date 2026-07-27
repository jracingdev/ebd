// Edge Function: sync Editora Betel catalog into betel_catalog table.
// Deploy: supabase functions deploy sync-betel
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const now = new Date()
  const tri = Math.floor(now.getMonth() / 3) + 1
  const year = now.getFullYear()
  const url = `https://www.editorabetel.com.br/escola-dominical-${tri}-trimestre-${year}`

  const html = await fetch(url, { headers: { 'User-Agent': 'EBDSync/1.0' } }).then((r) => r.text())
  const re = /href="(https:\/\/www\.editorabetel\.com\.br\/escola-dominical\/revista-[^"]+)"/g
  const links = [...html.matchAll(re)].map((m) => m[1])
  const unique = [...new Set(links)]

  let upserted = 0
  for (const produto_url of unique) {
    if (/professor/i.test(produto_url)) continue
    const page = await fetch(produto_url).then((r) => r.text())
    const capa = page.match(/https:\/\/www\.editorabetel\.com\.br\/uploads\/imagens\/[a-zA-Z0-9]+_m\.jpg/)?.[0]
    const sku = produto_url.match(/-(\d{6})$/)?.[1]
    const titulo = page.match(/<h1[^>]*>([^<]+)<\/h1>/i)?.[1]?.trim() ?? produto_url
    const grupo = mapGrupo(titulo)
    if (!grupo) continue
    const row = {
      grupo,
      trimestre: `${tri}º Trimestre ${year}`,
      serie: serieFrom(titulo),
      tema: titulo,
      sku,
      capa_url: capa,
      produto_url,
      synced_at: new Date().toISOString(),
    }
    const { error } = await supabase.from('betel_catalog').upsert(row, { onConflict: 'grupo,trimestre' })
    if (!error) upserted++
  }

  return new Response(JSON.stringify({ ok: true, upserted, tri, year }), {
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
})

function mapGrupo(t: string): string | null {
  const u = t.toUpperCase()
  if (u.includes('CRESCER') || u.includes('MATERNAL')) return 'Maternal (2-3 anos)'
  if (u.includes('CONHECER') || u.includes('PRE')) return 'Pré-escolar (4-5 anos)'
  if (u.includes('APRENDER') || u.includes('PRIMAR')) return 'Primários (6-8 anos)'
  if (u.includes('SABER') || u.includes('JUNIOR')) return 'Juniores (9-11 anos)'
  if (u.includes('ADOLESCER') || u.includes('12')) return 'Adolescentes 12-14'
  if (u.includes('VIVER') || u.includes('15')) return 'Adolescentes 15-17'
  if (u.includes('CONECTAR') || u.includes('JOVENS')) return 'Jovens'
  if (u.includes('ADULTO')) return 'CIBE'
  return null
}

function serieFrom(t: string): string {
  const u = t.toUpperCase()
  if (u.includes('CRESCER')) return 'CRESCER+'
  if (u.includes('CONHECER')) return 'CONHECER+'
  if (u.includes('APRENDER')) return 'APRENDER+'
  if (u.includes('SABER')) return 'SABER+'
  if (u.includes('ADOLESCER')) return 'ADOLESCER+'
  if (u.includes('VIVER')) return 'VIVER+'
  if (u.includes('CONECTAR')) return 'CONECTAR+'
  return 'Betel Dominical Adulto'
}
