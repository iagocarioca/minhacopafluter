import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/models/site_assets.dart';
import '../../publico/data/site_assets_remote_data_source.dart';
import '../state/auth_controller.dart';
import 'widgets/auth_premium_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authController,
    required this.config,
    required this.siteAssetsDataSource,
  });

  final AuthController authController;
  final AppConfig config;
  final SiteAssetsRemoteDataSource siteAssetsDataSource;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  SiteAssets? _siteAssets;

  @override
  void initState() {
    super.initState();
    _loadSiteAssets();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteAssets() async {
    try {
      final assets = await widget.siteAssetsDataSource.getPublicSiteAssets();
      if (!mounted) return;
      setState(() => _siteAssets = assets);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.authController.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go('/home');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.authController.errorMessage ?? 'Falha no login'),
      ),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final loading = widget.authController.isLoading;

        return AuthPremiumLayout(
          headlineTop: 'Acesse sua conta',
          headlineBottom:
              'Entre para acompanhar partidas, rankings e estatisticas em tempo real.',
          watermark: 'ENTRAR',
          brandLabel: 'MINHACOPA',
          showBack: false,
          logoOnlyHeader: true,
          centerContent: true,
          contentMaxWidth: 370,
          logoImageUrl: widget.config.resolveApiImageUrl(_siteAssets?.logoUrl),
          headerBackgroundImageUrl: widget.config.resolveApiImageUrl(
            _siteAssets?.bannerUrl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Oi! Voce ja tem uma conta?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2E3541),
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  style: const TextStyle(
                    color: Color(0xFF2A313C),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: authPillInputDecoration(hintText: 'Usuario'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o usuario';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(
                    color: Color(0xFF2A313C),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: authPillInputDecoration(
                    hintText: 'Senha',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: const Color(0x994B5361),
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a senha';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 14),
                AuthPrimaryButton(
                  label: 'ENTRAR',
                  onPressed: loading ? null : _submit,
                  loading: loading,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => _showComingSoon(
                              'Recuperacao de senha em breve.',
                            ),
                      child: const Text('Esqueci minha senha'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => context.go('/register'),
                      child: const Text('Criar conta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
