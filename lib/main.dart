import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'views/auth/auth_screen.dart';
import 'views/main_shell/main_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SupabaseService()),
      ],
      child: const PnumaDeskApp(),
    ),
  );
}

class PnumaDeskApp extends StatelessWidget {
  const PnumaDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PnumaDesk Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Consumer<SupabaseService>(
        builder: (context, supabase, _) {
          if (supabase.isLoggedIn) {
            return const MainShellScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
