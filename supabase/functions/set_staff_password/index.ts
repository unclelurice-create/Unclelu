// Owner menimpa password staff di toko yang sama. Password lama langsung tidak berlaku.
import { cors, json, requireOwner, staffOfStore } from "../_shared/owner.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const ctx = await requireOwner(req);
  if (ctx instanceof Response) return ctx;
  const { user_id, password } = await req.json().catch(() => ({}));
  const p = String(password ?? "");
  if (p.length < 6) return json({ error: "PASSWORD_PENDEK" }, 400);
  const target = await staffOfStore(ctx.admin, String(user_id), ctx.storeId);
  if (!target || target.role !== "staff") return json({ error: "BUKAN_STAFF_TOKO_INI" }, 403);
  const { error } = await ctx.admin.auth.admin.updateUserById(target.id, { password: p });
  if (error) return json({ error: "GAGAL_MENYIMPAN" }, 500);
  return json({ ok: true });
});
