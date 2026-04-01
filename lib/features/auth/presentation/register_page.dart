import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/models/site_assets.dart';
import '../../publico/data/site_assets_remote_data_source.dart';
import '../state/auth_controller.dart';
import 'widgets/auth_premium_layout.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authController,
    required this.config,
    required this.siteAssetsDataSource,
  });

  final AuthController authController;
  final AppConfig config;
  final SiteAssetsRemoteDataSource siteAssetsDataSource;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreeTerms = false;
  SiteAssets? _siteAssets;

  @override
  void initState() {
    super.initState();
    _loadSiteAssets();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
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
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aceite os termos para continuar.')),
      );
      return;
    }

    final success = await widget.authController.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso.')),
      );
      context.go('/login');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.authController.errorMessage ?? 'Falha no cadastro',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final loading = widget.authController.isLoading;

        return AuthPremiumLayout(
          headlineTop: 'Crie seu ID na MinhaCopa',
          headlineBottom:
              'Receba noticias, destaques e atualizacoes dos seus times favoritos.',
          watermark: 'JUNTE',
          brandLabel: 'MINHACOPA',
          showBack: false,
          logoOnlyHeader: true,
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
                  'Criar conta',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2E3541),
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  style: const TextStyle(
                    color: Color(0xFF2A313C),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: authPillInputDecoration(
                    hintText: 'Nome de usuario',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o usuario';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(
                    color: Color(0xFF2A313C),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: authPillInputDecoration(hintText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o email';
                    }
                    if (!value.contains('@')) return 'Email invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
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
                    if (value.length < 6) {
                      return 'Minimo de 6 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Senha com no minimo 8 caracteres, incluindo 1 maiuscula e 1 simbolo.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF676E7A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: loading
                      ? null
                      : () => setState(() => _agreeTerms = !_agreeTerms),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreeTerms,
                          onChanged: loading
                              ? null
                              : (value) => setState(
                                  () => _agreeTerms = value ?? false,
                                ),
                          visualDensity: VisualDensity.compact,
                          activeColor: const Color(0xFFFF3B4D),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Text(
                              'Concordo com os Termos e Politica de Privacidade',
                              style: TextStyle(
                                color: Color(0xFF4B5361),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AuthPrimaryButton(
                  label: 'Criar conta',
                  onPressed: loading ? null : _submit,
                  loading: loading,
                  backgroundColor: const Color(0xFF1B1317),
                  foregroundColor: Colors.white,
                  borderRadius: 10,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ao clicar em criar conta, voce confirma que seus dados podem ser utilizados para operacao da plataforma.',
                  style: TextStyle(
                    color: Color(0xFF8B919D),
                    fontSize: 11.2,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: loading ? null : () => context.go('/login'),
                  child: const Text('Ja tenho conta'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
