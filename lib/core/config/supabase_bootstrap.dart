import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

/// Initializes the Supabase client. Call once in `main()` before `runApp`.
Future<void> bootstrapSupabase() async {
  if (!EnvConfig.isConfigured) {
    throw StateError(
      'Supabase is not configured. Run with '
      '--dart-define-from-file=env/dev.json (see env/dev.json.example).',
    );
  }
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );
}

/// Convenience accessor for the initialized client.
SupabaseClient get supabase => Supabase.instance.client;
