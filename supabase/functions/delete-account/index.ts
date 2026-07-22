// BurnReward — account deletion (Apple Guideline 5.1.1(v)).
//
// The app ships only the restricted publishable key, which cannot delete an
// auth user. This Edge Function runs with the service role to do it safely:
// it authenticates the caller from their own JWT (never a body-supplied id),
// removes their post photos from storage (those do NOT cascade when the auth
// user is deleted), then deletes the auth user — which cascades every row
// keyed to their profile (profile, shared_character, posts, reactions, scores,
// friendships/blocks, reports) via the `on delete cascade` foreign keys.
//
// Deploy:  supabase functions deploy delete-account
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by the
// Edge runtime — no secrets to set by hand, and the service role never ships
// in the app.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "Missing Authorization" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  // 1. Identify the caller from their token. The user can only ever delete
  //    themselves — the id is never taken from the request body.
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData.user) return json({ error: "Invalid session" }, 401);
  const uid = userData.user.id;

  // 2. Remove their post photos. Paths are <uid>/<eventId>/<n>.jpg — two levels
  //    under the user's folder. Best-effort: a lingering photo must not block
  //    the account deletion, but we surface it so orphans can be swept.
  let photoWarning: string | null = null;
  try {
    const paths: string[] = [];
    const { data: events } = await admin.storage.from("post-photos").list(uid, { limit: 1000 });
    for (const ev of events ?? []) {
      const { data: files } = await admin.storage
        .from("post-photos")
        .list(`${uid}/${ev.name}`, { limit: 1000 });
      for (const f of files ?? []) paths.push(`${uid}/${ev.name}/${f.name}`);
    }
    if (paths.length) {
      const { error } = await admin.storage.from("post-photos").remove(paths);
      if (error) photoWarning = error.message;
    }
  } catch (e) {
    photoWarning = e instanceof Error ? e.message : "photo cleanup failed";
  }

  // 3. Delete the auth user → cascades every row keyed to their profile.
  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) return json({ error: delErr.message }, 500);

  return json({ ok: true, photoWarning });
});
