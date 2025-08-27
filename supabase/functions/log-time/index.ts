
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
  const { person_email, project_id, work_date, hours } = await req.json();
  const { data: person } = await supabase.from('hr.people').select('id').eq('email', person_email).single();
  if (!person) throw new Error("person not found");

  const { data: rate } = await supabase.rpc('cost.get_latest_rate', { p_person: person.id, p_date: work_date ?? null });
  const rate_snapshot = rate?.[0]?.internal_cost_rate ?? null;
  const bill_rate_snapshot = rate?.[0]?.bill_rate ?? null;

  const { error } = await supabase.from('cost.timesheets').insert({
    person_id: person.id, project_id, work_date, hours, rate_snapshot, bill_rate_snapshot
  });
  if (error) throw error;
  return { message: "logged" };
}
