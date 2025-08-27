
// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = "https://leeqayaitvyvwmyntofh.supabase.co";
// fallback only for quick start (move to ENV in production)
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxlZXFheWFpdHZ5dndteW50b2ZoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Mzk1NDM5MSwiZXhwIjoyMDY5NTMwMzkxfQ.3cc2lufd8zCUo2LS4yP_EXOLVqy1ml4n_AIYgUBWdII";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...cors } });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("", { status: 204, headers: cors });
  try {
    const auth = req.headers.get("authorization") ?? "";
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: auth } }
    });

    // handler body
    const result = await handler(req, supabase);
    return json({ ok: true, ...result });
  } catch (e) {
    return json({ ok: false, error: String(e?.message ?? e) }, 400);
  }
});


async function handler(req: Request, supabase: any) {
  const { email, new_role_y } = await req.json();
  if (!email || !new_role_y) throw new Error("email/new_role_y required");

  const { data: person } = await supabase.from('hr.people').select('id').eq('email', email).single();
  if (!person) throw new Error("person not found");

  await supabase.from('hr.role_history').insert({ person_id: person.id, new_role_y });
  await supabase.from('hr.people').update({ role_y: new_role_y, updated_at: new Date().toISOString() }).eq('id', person.id);

  return { message: "role changed" };
}
