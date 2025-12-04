import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // For Signup
  
  bool _isLoading = false;
  bool _isSignUp = false; // Toggle between Login and Signup
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // Start slightly below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final supabase = Supabase.instance.client;

    try {
      if (_isSignUp) {
        // 1. Create Account
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _nameController.text.trim()}, // Metadata
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Please check your email to confirm.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Switch back to login view
          setState(() => _isSignUp = false);
        }
      } else {
        // 2. Login
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          // Extract user's full name from metadata
          final user = response.user;
          if (user != null) {
            final fullName = user.userMetadata?['full_name'] as String?;
            if (fullName != null && fullName.isNotEmpty) {
              AppState.currentUserName = fullName;
            } else {
              // Fallback to email username if no full name
              AppState.currentUserName = email.split('@')[0];
            }
          }
          
          // Fetch User Role from Database
          final userRoleRes = await supabase
              .from('app_users')
              .select('*, roles(role_name)')
              .eq('email', email)
              .maybeSingle();

          if (userRoleRes != null) {
            final roleData = userRoleRes['roles'];
            final roleName = roleData != null ? roleData['role_name'] : 'User';
            
            // Map role name to Enum
            if (roleName.toString().toLowerCase() == 'service manager') {
              AppState.currentRole = UserRole.serviceManager;
            } else {
              AppState.currentRole = UserRole.admin;
            }
          } else {
            // Default fallback
            AppState.currentRole = UserRole.admin;
          }

          // Reset welcome flag on new login
          AppState.hasShownWelcome = false;

          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first.');
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Error sending reset email: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626), // Red error color
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          if (isDesktop) {
            return Row(
              children: [
                // LEFT SIDE: Hero / Brand Area
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A), // Dark Slate
                          Color(0xFF1E3A8A), // Brand Blue
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative Circles
                        Positioned(
                          top: -100,
                          left: -100,
                          child: Container(
                            width: 400,
                            height: 400,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -50,
                          right: -50,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Image.asset(
                                  'lib/image/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 40),
                              const Text(
                                'G & J Solutions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Efficiency in every degree.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // RIGHT SIDE: Form Area
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildFormContent(isDark: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // MOBILE: Glassmorphism Style
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E3A8A), // Brand Blue
                    Color(0xFFF8FAFC), // Light Slate
                  ],
                  stops: [0.0, 0.6],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Logo on top for mobile
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'lib/image/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Glass Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(32),
                        child: _buildFormContent(isDark: false),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFormContent({required bool isDark}) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conditional Header Text (Register Only)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSignUp
                    ? Column(
                        children: const [
                          Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 32),
                        ],
                      )
                    : const SizedBox(height: 0), // No spacer for Login
              ),

              // Fields
              AutofillGroup(
            child: Column(
              children: [
                AnimatedCrossFade(
                  firstChild: Container(),
                  secondChild: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        isLast: false,
                        validator: (v) {
                          if (!_isSignUp) return null;
                          if (v == null || v.isEmpty) return 'Full Name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  crossFadeState: _isSignUp
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  inputType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  isLast: false,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isObscure: _obscurePassword,
                  onToggleObscure: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  autofillHints: const [AutofillHints.password],
                  isLast: true,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),

          // Forgot Password
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState: !_isSignUp
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          
          const SizedBox(height: 32),

          // Submit Button
          Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2563EB), // Blue
                  Color(0xFF1D4ED8), // Darker Blue
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Toggle Login/Signup
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _isSignUp
                    ? 'Already have an account?'
                    : 'Don\'t have an account?',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _isSignUp ? 'Sign In' : 'Create Account',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
}

Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? inputType,
    List<String>? autofillHints,
    required bool isLast,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {

    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: inputType,
      autofillHints: autofillHints,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500), // Darker Slate
        prefixIcon: Icon(icon, size: 22, color: const Color(0xFF475569)), // Darker Slate
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 22,
                  color: const Color(0xFF475569), // Darker Slate
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
      validator: validator ?? (v) {
        if (v == null || v.isEmpty) return '$label is required';
        if (inputType == TextInputType.emailAddress && !v.contains('@')) {
          return 'Enter a valid email';
        }
        if (isPassword && v.length < 6) return 'Min 6 characters';
        return null;
      },
    );
  }
}
