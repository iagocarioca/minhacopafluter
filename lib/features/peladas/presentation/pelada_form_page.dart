import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/image_file_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/pelada.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class PeladaFormPage extends StatefulWidget {
  const PeladaFormPage.create({
    super.key,
    required this.dataSource,
    required this.config,
  }) : peladaId = null;

  const PeladaFormPage.edit({
    super.key,
    required this.peladaId,
    required this.dataSource,
    required this.config,
  });

  final int? peladaId;
  final PeladasRemoteDataSource dataSource;
  final AppConfig config;

  bool get isEditing => peladaId != null;

  @override
  State<PeladaFormPage> createState() => _PeladaFormPageState();
}

class _PeladaFormPageState extends State<PeladaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _instagramController = TextEditingController();
  final _fusoController = TextEditingController(text: 'America/Sao_Paulo');
  final _corPrimariaController = TextEditingController(text: '#FF3B4D');
  final _corSecundariaController = TextEditingController();

  bool _ativa = true;
  bool _loading = false;
  bool _loadingInitial = false;
  String? _error;
  Pelada? _existing;

  XFile? _logoFile;
  XFile? _logoVetorFile;
  XFile? _perfilFile;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cidadeController.dispose();
    _instagramController.dispose();
    _fusoController.dispose();
    _corPrimariaController.dispose();
    _corSecundariaController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });

    try {
      final data = await widget.dataSource.getPelada(widget.peladaId!);
      if (!mounted) return;

      _existing = data;
      _nomeController.text = data.nome;
      _cidadeController.text = data.cidade;
      _instagramController.text = data.instagramUrl ?? '';
      _fusoController.text = data.fusoHorario ?? 'America/Sao_Paulo';
      if (data.cores.isNotEmpty) {
        _corPrimariaController.text = data.cores.first;
      }
      if (data.cores.length > 1) {
        _corSecundariaController.text = data.cores[1];
      }
      _ativa = data.ativa;
    } catch (error) {
      if (!mounted) return;
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loadingInitial = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final input = PeladaUpsertInput(
      nome: _nomeController.text.trim(),
      cidade: _cidadeController.text.trim(),
      instagramUrl: _instagramController.text.trim(),
      fusoHorario: _fusoController.text.trim(),
      corPrimaria: _corPrimariaController.text.trim(),
      corSecundaria: _corSecundariaController.text.trim().isEmpty
          ? null
          : _corSecundariaController.text.trim(),
      ativa: _ativa,
      logoFile: _logoFile,
      logoVetorFile: _logoVetorFile,
      perfilFile: _perfilFile,
    );

    try {
      if (widget.isEditing) {
        await widget.dataSource.updatePelada(
          id: widget.peladaId!,
          input: input,
        );
      } else {
        await widget.dataSource.createPelada(input);
      }

      if (!mounted) return;
      context.go('/peladas');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe $label';
    }
    return null;
  }

  String? _validateColor(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe a cor';
    final normalized = value.trim().startsWith('#')
        ? value.trim()
        : '#${value.trim()}';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      return 'Use formato #RRGGBB';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: Text(widget.isEditing ? 'Editar Pelada' : 'Nova Pelada'),
      ),
      body: _loadingInitial
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Pelada',
                        ),
                        validator: (value) => _required(value, 'o nome'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cidadeController,
                        decoration: const InputDecoration(labelText: 'Cidade'),
                        validator: (value) => _required(value, 'a cidade'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _instagramController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Instagram (opcional)',
                          hintText: '@sua_pelada ou link completo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fusoController,
                        decoration: const InputDecoration(
                          labelText: 'Fuso Horario',
                        ),
                        validator: (value) =>
                            _required(value, 'o fuso horario'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _corPrimariaController,
                        decoration: const InputDecoration(
                          labelText: 'Cor primaria',
                        ),
                        validator: _validateColor,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _corSecundariaController,
                        decoration: const InputDecoration(
                          labelText: 'Cor secundaria (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pelada ativa'),
                        value: _ativa,
                        onChanged: (value) => setState(() => _ativa = value),
                      ),
                      const SizedBox(height: 12),
                      ImageFilePickerField(
                        label: 'Logo',
                        initialImageUrl: widget.config.resolveApiImageUrl(
                          _existing?.logoUrl,
                        ),
                        onChanged: (file) => _logoFile = file,
                      ),
                      const SizedBox(height: 12),
                      ImageFilePickerField(
                        label: 'Logo Vetor (PNG)',
                        initialImageUrl: widget.config.resolveApiImageUrl(
                          _existing?.logoVetorUrl,
                        ),
                        onChanged: (file) => _logoVetorFile = file,
                      ),
                      const SizedBox(height: 12),
                      ImageFilePickerField(
                        label: 'Foto de Capa',
                        initialImageUrl: widget.config.resolveApiImageUrl(
                          _existing?.perfilUrl,
                        ),
                        onChanged: (file) => _perfilFile = file,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing ? 'Salvar' : 'Criar Pelada',
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
