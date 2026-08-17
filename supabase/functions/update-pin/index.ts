import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Ambil JWT dari Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const userJwt = authHeader.replace("Bearer ", "");

    // 2. Parse seluruh body sekaligus
    // Body fields:
    //   profile_id  : UUID profil yang akan diupdate
    //   new_pin_hash: SHA-256 hash dari PIN baru (untuk disimpan di profiles)
    //   new_pin     : PIN baru plaintext (untuk disync ke Supabase Auth password)
    const body = await req.json() as {
      profile_id?: string;
      new_pin_hash?: string;
      new_pin?: string;
    };

    const { profile_id, new_pin_hash, new_pin } = body;

    if (!profile_id || !new_pin_hash || !new_pin) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: profile_id, new_pin_hash, new_pin" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 3. Buat admin client — service-role key aman di sini karena ini server-side
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // 4. Verifikasi JWT — jika user punya session, pastikan hanya update miliknya
    //    Untuk alur lupa PIN: user tidak punya session aktif, userError akan truthy
    //    tapi kita tetap lanjutkan karena sudah diverifikasi via OTP + TTL di app
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(userJwt);
    const hasActiveSession = !userError && !!userData?.user;

    if (hasActiveSession && userData.user.id !== profile_id) {
      return new Response(
        JSON.stringify({ error: "Forbidden: cannot update another user's PIN" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 5. Ambil pin_hash lama dulu untuk rollback jika gagal
    const { data: existingProfile, error: fetchError } = await supabaseAdmin
      .from("profiles")
      .select("pin_hash")
      .eq("id", profile_id)
      .single();

    if (fetchError || !existingProfile) {
      return new Response(
        JSON.stringify({ error: "Profile not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const oldPinHash = existingProfile.pin_hash as string;

    // 6. Update pin_hash di tabel profiles
    const { data: updatedProfile, error: profileUpdateError } = await supabaseAdmin
      .from("profiles")
      .update({
        pin_hash: new_pin_hash,
        updated_at: new Date().toISOString(),
      })
      .eq("id", profile_id)
      .select()
      .single();

    if (profileUpdateError || !updatedProfile) {
      console.error("Profile pin_hash update failed:", profileUpdateError);
      return new Response(
        JSON.stringify({
          error: "Failed to update profile PIN",
          detail: profileUpdateError?.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 7. Sync password Supabase Auth agar signInWithPassword tetap bisa pakai PIN baru
    const { error: authUpdateError } = await supabaseAdmin.auth.admin.updateUserById(
      profile_id,
      { password: new_pin },
    );

    if (authUpdateError) {
      console.error("Auth password sync failed:", authUpdateError);

      // Rollback: kembalikan pin_hash lama di profiles
      await supabaseAdmin
        .from("profiles")
        .update({ pin_hash: oldPinHash, updated_at: new Date().toISOString() })
        .eq("id", profile_id);

      return new Response(
        JSON.stringify({
          error: "Failed to sync PIN to auth password — profile rolled back",
          detail: authUpdateError.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, profile: updatedProfile }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
