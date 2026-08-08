import '../config/env.dart';
import '../services/supabase_client.dart';
import 'memory_sori_repository.dart';
import 'sori_repository.dart';
import 'supabase_sori_repository.dart';

/// Env 기준으로 Memory | Supabase Repository 선택.
SoriRepository createSoriRepository() {
  if (Env.hasSupabaseConfig && SoriSupabase.isInitialized) {
    return SupabaseSoriRepository();
  }
  return MemorySoriRepository();
}
