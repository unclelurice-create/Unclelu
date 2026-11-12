// Owner menambah staff: buat akun (email + password dari owner) dan profil berrole staff.
import { cors, json, requireOwner } from "../_shared/owner.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const ctx = await requireOwner(req);
  if (ctx instanceof Response) return ctx;
  const { name, email, password } = await req.json().catch(() => ({}));
  const n = String(name ?? "").trim(), e = String(email ?? "").trim().toLowerCase(), p = String(password ?? "");
  if (!n || !/^\S+@\S+$/.test(e)) return json({ error: "DATA_TIDAK_VALID" }, 400);
  if (p.length < 6) return json({ error: "PASSWORD_PENDEK" }, 400);
  const { data, error } = await ctx.admin.auth.admin.createUser({
    email: e, password: p, email_confirm: true, user_metadata: { invited: "true", full_name: n },
  });
  if (error || !data.user) {
    const dup = /already|registered|exists/i.test(error?.message ?? "");
    return json({ error: dup ? "EMAIL_TERDAFTAR" : "GAGAL_MEMBUAT" }, dup ? 409 : 500);
  }
  const { error: pErr } = await ctx.admin.from("profiles").insert({
    id: data.user.id, full_name: n, email: e, role: "staff", store_id: ctx.storeId,
  });
  if (pErr) {
    await ctx.admin.auth.admin.deleteUser(data.user.id);
    return json({ error: "GAGAL_MEMBUAT" }, 500);
  }
  return json({ id: data.user.id });
});
