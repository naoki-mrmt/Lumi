// Lumi: delete-account Edge Function
//
// 認証済みユーザの自己削除を行う。
// クライアントから JWT 付き fetch で呼び出され、auth.admin.deleteUser で
// auth.users から削除 → 関連 RLS データは ON DELETE CASCADE で連鎖削除される想定。
//
// クライアントは LiveSupabaseAuthClient.deleteAccount() からこの関数を呼び出す。

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // 1. 呼び出し元の JWT からユーザを特定
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }
  const userJWT = authHeader.replace("Bearer ", "");

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${userJWT}` } },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return new Response(JSON.stringify({ error: "Invalid user" }), { status: 401 });
  }
  const userId = userData.user.id;

  // 2. service_role で auth.admin.deleteUser を実行
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const { error: deleteErr } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteErr) {
    return new Response(
      JSON.stringify({ error: deleteErr.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ deletedUserId: userId }),
    { headers: { "Content-Type": "application/json" } },
  );
});
