// Lumi: cleanup-expired-codes Edge Function
//
// 試合コード有効期限切れのものを定期的にクリーンアップ。
// pg_cron で1日1回呼び出す想定。
//
// matches.match_code は UNIQUE 制約なので、有効期限切れのものは
// match_code を NULL にすることで再利用可能に (status は abandoned へ)。

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

serve(async (req: Request) => {
  // 認証 (Cron 用シークレット or Service Role)
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.includes(SUPABASE_SERVICE_ROLE_KEY) && !auth.includes(Deno.env.get("CRON_SECRET") ?? "")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // 24時間以上前に期限切れになったコードを処理
  const { data, error } = await supabase
    .from("matches")
    .update({ status: "abandoned" })
    .lt("match_code_expires_at", new Date().toISOString())
    .neq("status", "finished")
    .neq("status", "abandoned")
    .select("id");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(
    JSON.stringify({ cleaned: data?.length ?? 0 }),
    { headers: { "Content-Type": "application/json" } },
  );
});
