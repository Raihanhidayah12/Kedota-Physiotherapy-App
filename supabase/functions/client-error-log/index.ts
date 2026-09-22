import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json() as {
      source?: string;
      method?: string;
      path?: string;
      status_code?: number;
      message?: string;
      platform?: string;
    };

    if (
      body.source !== "flutter_client" ||
      !body.method ||
      !body.path ||
      typeof body.status_code !== "number" ||
      body.status_code < 500 ||
      body.status_code > 599
    ) {
      return new Response(JSON.stringify({ error: "Invalid 5xx log payload" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const receivedAt = new Date().toISOString();

    // Log to Supabase Edge Function Logs (always — cheap, instant)
    console.error("Client received server 5xx:", JSON.stringify({
      ...body,
      received_at: receivedAt,
    }));

    // Persist to error_logs table using service_role key so it bypasses RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (supabaseUrl && serviceRoleKey) {
      const supabase = createClient(supabaseUrl, serviceRoleKey, {
        auth: { persistSession: false },
      });

      const { error: insertError } = await supabase
        .from("error_logs")
        .insert({
          source: body.source,
          method: body.method,
          path: body.path,
          status_code: body.status_code,
          message: body.message ?? null,
          platform: body.platform ?? null,
          received_at: receivedAt,
        });

      if (insertError) {
        // Log the insert failure but still return 202 — the console.error above
        // already captured the event, so we don't want to surface this to the client.
        console.error("error_logs insert failed:", insertError.message);
      }
    } else {
      console.warn(
        "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set; skipping DB insert",
      );
    }

    return new Response(JSON.stringify({ accepted: true }), {
      status: 202,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Client error log processing failed:", error);
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
