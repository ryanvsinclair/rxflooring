(function () {
  if (!window.supabase || !window.RX_SUPABASE_URL || !window.RX_SUPABASE_ANON_KEY) {
    console.error("Supabase config or library missing");
    return;
  }
  window.rxSupabase = window.supabase.createClient(
    window.RX_SUPABASE_URL,
    window.RX_SUPABASE_ANON_KEY,
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    }
  );
})();
