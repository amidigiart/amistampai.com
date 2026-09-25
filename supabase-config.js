var SUPABASE_URL = 'https://aywcfyfqvusawqbfhwhs.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_1SpMklrPQqZBfKqFpFRwaA_QNxN1RBw';
// Supabase does not publish whether wallet sign-in is on; keep this in sync with
// Authentication → Sign In / Providers → Web3 Wallet → Ethereum (enabled 2026-09-25).
var WEB3_LOGIN_ENABLED = true;

var _supabase = null;
function getSupabase() {
  if (!_supabase && window.supabase) {
    // passkeys are a Supabase Auth beta and need this explicit opt-in
    _supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { experimental: { passkey: true } }
    });
  }
  return _supabase;
}
