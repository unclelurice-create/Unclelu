// Helper bersama: verifikasi pemanggil adalah Owner/Admin dan siapkan admin client.
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

export type OwnerCtx = { admin: SupabaseClient; callerId: string; storeId: string };

export async function requireOwner(req: Request): Promise<OwnerCtx | Response> {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "TIDAK_LOGIN" }, 401);
  const admin = createClient(url, service, { auth: { persistSession: false } });
  const { data: me } = await admin.from("profiles").select("role, store_id").eq("id", user.id).single();
  if (!me || me.role !== "owner") return json({ error: "KHUSUS_OWNER" }, 403);
  return { admin, callerId: user.id, storeId: me.store_id };
}

export async function staffOfStore(admin: SupabaseClient, userId: string, storeId: string) {
  const { data } = await admin.from("profiles").select("id, role, store_id").eq("id", userId).single();
  return data && data.store_id === storeId ? data : null;
}
