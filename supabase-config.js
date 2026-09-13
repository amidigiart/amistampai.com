var SUPABASE_URL = 'https://aywcfyfqvusawqbfhwhs.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_1SpMklrPQqZBfKqFpFRwaA_QNxN1RBw';

var _supabase = null;
function getSupabase() {
  if (!_supabase && window.supabase) {
    _supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return _supabase;
}
