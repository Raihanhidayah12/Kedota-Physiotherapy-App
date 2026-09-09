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

    console.error("Client received server 5xx:", JSON.stringify({
      ...body,
      received_at: new Date().toISOString(),
    }));

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