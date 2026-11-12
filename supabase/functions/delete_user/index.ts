// Owner menghapus pengguna di tokonya. Tidak boleh hapus diri sendiri,
// dan harus tetap ada minimal satu Owner/Admin.
import { cors, json, requireOwner, staffOfStore } from "../_shared/owner.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const ctx = await requireOwner(req);
  if (ctx instanceof Response) return ctx;
  const { user_id } = await req.json().catch(() => ({}));
  if (String(user_id) === ctx.callerId) return json({ error: "TIDAK_BISA_HAPUS_DIRI" }, 400);
  const target = await staffOfStore(ctx.admin, String(user_id), ctx.storeId);
  if (!target) return json({ error: "BUKAN_PENGGUNA_TOKO_INI" }, 403);
  if (target.role === "owner") {
    const { count } = await ctx.admin.from("profiles").select("id", { count: "exact", head: true })
      .eq("store_id", ctx.storeId).eq("role", "owner");
    if ((count ?? 0) <= 1) return json({ error: "MINIMAL_SATU_OWNER" }, 400);
  }
  const { error } = await ctx.admin.auth.admin.deleteUser(target.id);
  if (error) return json({ error: "GAGAL_MENGHAPUS" }, 500);
  return json({ ok: true });
});
