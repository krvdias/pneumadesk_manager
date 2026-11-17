import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/supabase_service.dart';
import 'database_configuration_dialog.dart';
import '../common/static_page_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  late AppEnvironment _selectedEnv;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    _selectedEnv = supabase.currentEnv;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username and password.');
      return;
    }

    final supabaseService = Provider.of<SupabaseService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isLogin) {
      final res = await supabaseService.login(
        username: username,
        password: password,
        env: _selectedEnv,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!res['success']) {
        setState(() => _errorMessage = res['message']);
      }
    } else {
      if (password != _confirmPasswordController.text.trim()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Passwords do not match.';
        });
        return;
      }

      await supabaseService.initEnvironment(_selectedEnv);
      final res = await supabaseService.register(
        username: username,
        password: password,
        mobile: _mobileController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success']) {
        final isFirst = res['isFirst'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              isFirst
                  ? 'Super Admin created successfully! Please log in.'
                  : 'Account created! Needs approval from Admin/Super Admin before login.',
            ),
          ),
        );
        setState(() {
          _isLogin = true;
          _passwordController.clear();
          _confirmPasswordController.clear();
          _mobileController.clear();
        });
      } else {
        setState(() => _errorMessage = res['message']);
      }
    }
  }

  void _openDatabaseConfiguration() {
    showDialog(
      context: context,
      builder: (context) => DatabaseConfigurationDialog(
        initialEnv: _selectedEnv,
        onEnvironmentChanged: (newEnv) {
          setState(() {
            _selectedEnv = newEnv;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top right settings icon button
          Positioned(
            top: 24,
            right: 24,
            child: Tooltip(
              message: 'Configure Database & Schema',
              child: InkWell(
                onTap: _openDatabaseConfiguration,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Main Center Login / Register Card
          Center(
            child: SingleChildScrollView(
              child: Container(
            width: 460,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo / Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.dns_rounded, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'PnumaDesk Manager',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Sign in to your management workspace' : 'Register a new management account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedEnv == AppEnvironment.live
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6366F1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedEnv == AppEnvironment.live
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedEnv.name.toUpperCase()} MODE ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedEnv == AppEnvironment.live
                                ? const Color(0xFF34D399)
                                : const Color(0xFF818CF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Error alert
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form Fields
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _isLogin ? _handleSubmit() : null,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                if (!_isLogin) ...[
                  TextField(
                    controller: _mobileController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (!_isLogin) ...[
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSubmit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_reset, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedEnv == AppEnvironment.live
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isLogin ? 'Sign In' : 'Create Account'),
                ),
                const SizedBox(height: 16),

                // Toggle between Login & Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? "Don't have an account? " : "Already registered? ",
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isLogin ? 'Register now' : 'Sign In',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFF334155)),
                const SizedBox(height: 12),

                // Footer links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => StaticPageDialog.showPrivacyPolicy(context),
                      child: const Text('Privacy Policy', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    const Text(' • ', style: TextStyle(color: Color(0xFF475569))),
                    InkWell(
                      onTap: () => StaticPageDialog.showTermsAndConditions(context),
                      child: const Text('Terms', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    const Text(' • ', style: TextStyle(color: Color(0xFF475569))),
                    InkWell(
                      onTap: () => StaticPageDialog.showContactUs(context),
                      child: const Text('Contact Us', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    const Text(' • ', style: TextStyle(color: Color(0xFF475569))),
                    const Text('v1.0.0', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}
}
