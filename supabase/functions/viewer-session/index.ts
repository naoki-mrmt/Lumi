// Lumi: viewer-session Edge Function
//
// 試合コードを受け取り、有効なら viewer_match_id をクレームに含む短期 JWT を発行。
// Viewer はこの JWT で Supabase に接続し、RLS ポリシーで特定試合のみ閲覧可。
//
// POST /functions/v1/viewer-session
// body: { "code": "ABC234" }
// 200: { "matchId": "...", "token": "...", "expiresAt": "..." }
// 400: { "error": "Invalid or expired code" }

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const JWT_SECRET = Deno.env.get("LUMI_VIEWER_JWT_SECRET")!;
const VIEWER_TOKEN_TTL_SECONDS = 3600; // 1時間

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  let body: { code?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const code = (body.code ?? "").trim().toUpperCase();
  if (code.length !== 6) {
    return jsonResponse({ error: "Code must be 6 characters" }, 400);
  }

  // RPC 経由で検証
  const { data: matchId, error } = await supabase.rpc("validate_match_code", { p_code: code });
  if (error || !matchId) {
    return jsonResponse({ error: "Invalid or expired code" }, 400);
  }

  // viewer_match_id を含む JWT を発行
  const expiresAt = new Date(Date.now() + VIEWER_TOKEN_TTL_SECONDS * 1000);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  const token = await create(
    { alg: "HS256", typ: "JWT" },
    {
      role: "anon",
      viewer_match_id: matchId,
      exp: getNumericDate(VIEWER_TOKEN_TTL_SECONDS),
    },
    key,
  );

  return jsonResponse({ matchId, token, expiresAt: expiresAt.toISOString() });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
