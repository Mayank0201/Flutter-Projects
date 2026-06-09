import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cinetracker/core/network/api_service.dart';
import 'package:cinetracker/core/utils/content_moderator.dart';
import 'package:cinetracker/core/storage/token_storage.dart';
import 'package:cinetracker/service/tmdb_service.dart';
import 'package:cinetracker/provider/wishlist_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../service/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  final storage = TokenStorage();
  final apiService = ApiService();
  final tmdbService = TMDBService();
  late final AuthService authService;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '961587425846-fvsaooog0c9qpkm6lshfmv6ial2o87ec.apps.googleusercontent.com',
    scopes: ['email'],
  );

  @override
  void initState() {
    super.initState();
    authService = AuthService(apiService);
  }

  void _showVerificationSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to read and click OK
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(
            Icons.mark_email_read_rounded,
            size: 64,
            color: colorScheme.primary,
          ),
          title: const Text(
            "Verify Your Email",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We sent a verification link to:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Please click the link in your email to activate your account before logging in.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(this.context).pop(); // Close register screen (go back to login)
                  },
                  child: const Text("Got It, Go to Login"),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void register() async {
    final username = usernameController.text.replaceAll(' ', '');
    final email = emailController.text.trim();
    final password = passwordController.text;

    final usernameError = ContentModerator.validateUsername(username);
    if (usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(usernameError)),
      );
      return;
    }

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required.")));
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address.")),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 8 characters long."),
        ),
      );
      return;
    }

    if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).*$').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must contain at least 1 uppercase letter and 1 number."),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await authService.register(username, email, password);

      if (!mounted) return;

      _showVerificationSuccessDialog(email);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed. Please try again.")),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<bool> _showUsernameSetupDialog(String initialAccessToken, String initialRefreshToken) async {
    final usernameController = TextEditingController();
    bool dialogLoading = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must set a username
      builder: (context) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final theme = Theme.of(context);
              
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text("Choose a Username"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Welcome to CineFolio! Please choose a unique username to complete your registration.",
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usernameController,
                      autofocus: true,
                      enabled: !dialogLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      decoration: InputDecoration(
                        labelText: "Username",
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        errorText: errorMessage,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                final username = usernameController.text.trim();
                                if (username.isEmpty || username.length < 3) {
                                  setDialogState(() {
                                    errorMessage = "Username must be at least 3 characters";
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  dialogLoading = true;
                                  errorMessage = null;
                                });
                                try {
                                  final updatedTokens = await authService.updateUsername(username);
                                  
                                  apiService.setToken(updatedTokens.accessToken);
                                  tmdbService.setToken(updatedTokens.accessToken);
                                  await storage.saveTokens(
                                    accessToken: updatedTokens.accessToken,
                                    refreshToken: updatedTokens.refreshToken,
                                  );
                                  
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop(true); // Close dialog returning true
                                } catch (e) {
                                  setDialogState(() {
                                    dialogLoading = false;
                                    errorMessage = e is AuthException ? e.message : "Failed to update username";
                                  });
                                }
                              },
                        child: dialogLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Save Username"),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> loginWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw AuthException("Failed to retrieve Google ID Token");
      }

      final tokens = await authService.googleLogin(idToken);
      apiService.setToken(tokens.accessToken);
      tmdbService.setToken(tokens.accessToken);
      await storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      if (tokens.isNewUser) {
        if (!mounted) return;
        final saved = await _showUsernameSetupDialog(tokens.accessToken, tokens.refreshToken);
        if (!saved) {
          apiService.clearToken();
          tmdbService.clearToken();
          await storage.clearTokens();
          return;
        }
      }

      if (!mounted) return;
      await context.read<WishlistProvider>().loadWatchlist();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (e) {
      debugPrint("Google login error: $e");
      if (!mounted) return;

      final message = e is AuthException ? e.message : "Google login failed";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  "Get Started",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  "Create your account to track movies",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: usernameController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Username",
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => register(),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text("Create Account"),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : loginWithGoogle,
                    icon: Image.network(
                      'https://developers.google.com/identity/images/g-logo.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 30,
                      ),
                    ),
                    label: const Text("Continue with Google"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: colorScheme.outline,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
