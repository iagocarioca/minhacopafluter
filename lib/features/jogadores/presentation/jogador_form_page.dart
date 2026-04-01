import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/image_file_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class JogadorFormPage extends StatefulWidget {
  const JogadorFormPage.create({
    super.key,
    required this.peladaId,
    required this.dataSource,
    required this.config,
  }) : jogadorId = null;

  const JogadorFormPage.edit({
    super.key,
    required this.peladaId,
    required this.jogadorId,
    required this.dataSource,
    required this.config,
  });

  final int peladaId;
  final int? jogadorId;
  final JogadoresRemoteDataSource dataSource;
  final AppConfig config;

  bool get isEditing => jogadorId != null;

  @override
  State<JogadorFormPage> createState() => _JogadorFormPageState();
}

class _JogadorFormPageState extends State<JogadorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _apelidoController = TextEditingController();
  final _telefoneController = TextEditingController();

  final List<String> _positions = const <String>[
    'Goleiro',
    'Zagueiro',
    'Lateral',
    'Meio-Campo',
    'Atacante',
  ];

  bool _ativo = true;
  bool _loading = false;
  bool _loadingInitial = false;
  String? _error;
  XFile? _fotoFile;
  Jogador? _existing;
  String? _selectedPosicao;

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
    _apelidoController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });

    try {
      final jogador = await widget.dataSource.getJogador(widget.jogadorId!);
      if (!mounted) return;
      _existing = jogador;
      _nomeController.text = jogador.nomeCompleto;
      _apelidoController.text = jogador.apelido;
      _telefoneController.text = jogador.telefone ?? '';
      _selectedPosicao = jogador.posicao;
      _ativo = jogador.ativo != false;
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
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

    final input = JogadorUpsertInput(
      nomeCompleto: _nomeController.text.trim(),
      apelido: _apelidoController.text.trim(),
      telefone: _telefoneController.text.trim().isEmpty
          ? null
          : _telefoneController.text.trim(),
      posicao: _selectedPosicao,
      ativo: _ativo,
      fotoFile: _fotoFile,
    );

    try {
      if (widget.isEditing) {
        await widget.dataSource.updateJogador(
          jogadorId: widget.jogadorId!,
          input: input,
        );
      } else {
        await widget.dataSource.createJogador(
          peladaId: widget.peladaId,
          input: input,
        );
      }

      if (!mounted) return;
      context.go('/peladas/${widget.peladaId}/jogadores');
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

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.config.resolveApiImageUrl(_existing?.fotoUrl);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: Text(widget.isEditing ? 'Editar Jogador' : 'Novo Jogador'),
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
                      ImageFilePickerField(
                        label: 'Foto',
                        initialImageUrl: existingImage,
                        shape: BoxShape.circle,
                        onChanged: (file) => _fotoFile = file,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        validator: (value) =>
                            _required(value, 'o nome completo'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apelidoController,
                        decoration: const InputDecoration(labelText: 'Apelido'),
                        validator: (value) => _required(value, 'o apelido'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedPosicao),
                        initialValue: _selectedPosicao,
                        decoration: const InputDecoration(labelText: 'Posicao'),
                        items: _positions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedPosicao = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Jogador ativo'),
                        value: _ativo,
                        onChanged: (value) => setState(() => _ativo = value),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
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
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
