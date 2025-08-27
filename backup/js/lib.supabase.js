
// web/js/lib.supabase.js
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';
export const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
