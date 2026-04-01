import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageFilePickerField extends StatefulWidget {
  const ImageFilePickerField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialImageUrl,
    this.shape = BoxShape.rectangle,
  });

  final String label;
  final void Function(XFile? file) onChanged;
  final String? initialImageUrl;
  final BoxShape shape;

  @override
  State<ImageFilePickerField> createState() => _ImageFilePickerFieldState();
}

class _ImageFilePickerFieldState extends State<ImageFilePickerField> {
  final ImagePicker _picker = ImagePicker();
  XFile? _file;
  Uint8List? _fileBytes;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _file = picked;
      _fileBytes = bytes;
    });
    widget.onChanged(picked);
  }

  void _clear() {
    setState(() {
      _file = null;
      _fileBytes = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _file != null || widget.initialImageUrl != null;
    final borderRadius = widget.shape == BoxShape.circle
        ? null
        : BorderRadius.circular(12);

    Widget imageWidget;
    if (_fileBytes != null) {
      imageWidget = Image.memory(
        _fileBytes!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else if (widget.initialImageUrl != null) {
      imageWidget = Image.network(
        widget.initialImageUrl!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else {
      imageWidget = const Icon(Icons.image_outlined, size: 30);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: widget.shape,
                borderRadius: borderRadius,
                color: Colors.white12,
                border: Border.all(color: Colors.transparent),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(child: imageWidget),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      hasImage ? 'Trocar imagem' : 'Selecionar imagem',
                    ),
                  ),
                  if (_file != null)
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remover nova seleção'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
