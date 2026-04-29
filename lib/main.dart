import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

import 'app.dart';
import 'shared/services/accounting_repository.dart';
import 'shared/services/supabase_config.dart';

void main() {
  final client = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
    authOptions: const AuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  final repository = AccountingRepository(client);

  runApp(EazyAccountApp(repository: repository));
}
