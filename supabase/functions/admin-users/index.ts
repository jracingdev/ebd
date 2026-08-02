// Edge Function: CRUD de usuários Auth + profiles (service role).
// Deploy: supabase functions deploy admin-users
// O app chama com o JWT do admin; a função valida role e usa SERVICE_ROLE.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type Role = 'aluno' | 'professor' | 'superintendente' | 'pastor' | 'admin'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Missing Authorization' }, 401)
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: authHeader } },
    })
    const admin = createClient(url, service)

    const { data: userData, error: userErr } = await userClient.auth.getUser()
    if (userErr || !userData.user) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const { data: caller, error: callerErr } = await admin
      .from('profiles')
      .select('id, role, ativo')
      .eq('id', userData.user.id)
      .maybeSingle()

    if (callerErr || !caller?.ativo) {
      return json({ error: 'Perfil inválido' }, 403)
    }
    const role = caller.role as Role
    if (!['admin', 'pastor', 'superintendente'].includes(role)) {
      return json({ error: 'Sem permissão para gerenciar usuários' }, 403)
    }

    const body = await req.json().catch(() => ({}))
    const action = body.action as string

    if (action === 'list') {
      const { data, error } = await admin
        .from('profiles')
        .select('*')
        .order('nome')
      if (error) return json({ error: error.message }, 500)
      return json({ users: data ?? [] })
    }

    if (action === 'create') {
      const matricula = String(body.matricula ?? '').trim()
      const nome = String(body.nome ?? '').trim()
      const senha = String(body.senha ?? '')
      const newRole = (body.role ?? 'aluno') as Role
      if (!matricula || !nome || !senha) {
        return json({ error: 'Informe matrícula, nome e senha.' }, 400)
      }
      if (role !== 'admin' && newRole === 'admin') {
        return json({ error: 'Somente admin pode criar outro admin.' }, 403)
      }

      const email =
        typeof body.email === 'string' && body.email.trim()
          ? body.email.trim()
          : `${matricula.toLowerCase().replace(/\s+/g, '')}@ebd.local`

      const { data: created, error: createErr } =
        await admin.auth.admin.createUser({
          email,
          password: senha,
          email_confirm: true,
          user_metadata: { matricula, nome, role: newRole },
        })
      if (createErr || !created.user) {
        return json({ error: createErr?.message ?? 'Falha ao criar Auth' }, 400)
      }

      const profile = {
        id: created.user.id,
        matricula,
        nome,
        role: newRole,
        grupo: body.grupo ?? null,
        telefone: body.telefone ?? null,
        email: body.email ?? email,
        aniversario: body.aniversario ?? null,
        ativo: body.ativo !== false,
        permission_overrides: body.permission_overrides ?? null,
      }
      const { data: row, error: upErr } = await admin
        .from('profiles')
        .upsert(profile)
        .select()
        .single()
      if (upErr) return json({ error: upErr.message }, 500)
      return json({ user: row })
    }

    if (action === 'update') {
      const matricula = String(body.matricula ?? '').trim()
      if (!matricula) return json({ error: 'Matrícula obrigatória' }, 400)

      const { data: before, error: findErr } = await admin
        .from('profiles')
        .select('*')
        .eq('matricula', matricula)
        .maybeSingle()
      if (findErr || !before) {
        return json({ error: 'Matrícula não encontrada.' }, 404)
      }

      if (
        before.role === 'admin' &&
        (body.role !== undefined && body.role !== 'admin' ||
          body.ativo === false)
      ) {
        const { count } = await admin
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('role', 'admin')
          .eq('ativo', true)
        if ((count ?? 0) <= 1) {
          return json(
            { error: 'Não é possível remover ou desativar o último administrador.' },
            400,
          )
        }
      }

      const patch: Record<string, unknown> = {}
      for (const k of [
        'nome',
        'role',
        'grupo',
        'telefone',
        'email',
        'aniversario',
        'ativo',
        'permission_overrides',
      ]) {
        if (body[k] !== undefined) patch[k] = body[k]
      }
      if (body.clear_grupo === true) patch.grupo = null
      if (body.clear_aniversario === true) patch.aniversario = null
      if (body.clear_permission_overrides === true) {
        patch.permission_overrides = null
      }
      if (role !== 'admin' && patch.role === 'admin') {
        return json({ error: 'Somente admin pode promover a admin.' }, 403)
      }

      const { data: row, error: upErr } = await admin
        .from('profiles')
        .update(patch)
        .eq('matricula', matricula)
        .select()
        .single()
      if (upErr) return json({ error: upErr.message }, 500)

      if (typeof body.nova_senha === 'string' && body.nova_senha.trim()) {
        const { error: pwErr } = await admin.auth.admin.updateUserById(
          before.id,
          { password: body.nova_senha.trim() },
        )
        if (pwErr) return json({ error: pwErr.message }, 400)
      }

      return json({ user: row })
    }

    if (action === 'reset_password') {
      const matricula = String(body.matricula ?? '').trim()
      const novaSenha = String(body.nova_senha ?? '')
      if (!matricula || !novaSenha) {
        return json({ error: 'Informe matrícula e nova senha.' }, 400)
      }
      const { data: before, error: findErr } = await admin
        .from('profiles')
        .select('id')
        .eq('matricula', matricula)
        .maybeSingle()
      if (findErr || !before) {
        return json({ error: 'Matrícula não encontrada.' }, 404)
      }
      const { error: pwErr } = await admin.auth.admin.updateUserById(before.id, {
        password: novaSenha,
      })
      if (pwErr) return json({ error: pwErr.message }, 400)
      return json({ ok: true })
    }

    return json({ error: `Ação desconhecida: ${action}` }, 400)
  } catch (e) {
    return json({ error: String(e) }, 500)
  }
})

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
