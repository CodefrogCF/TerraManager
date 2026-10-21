import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:terramanager/core/presentation/widgets/responsive_picture_frame.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

/// Keeps creation pictures local until the entity is saved.
class SharedCreationPictureField extends StatefulWidget {
  const SharedCreationPictureField({
    super.key,
    required this.picture,
    required this.enabled,
    required this.onChanged,
    required this.onProcessingChanged,
    this.pictureSelectionFlow,
  });

  final SelectedPicture? picture;
  final bool enabled;
  final ValueChanged<SelectedPicture?> onChanged;
  final ValueChanged<bool> onProcessingChanged;
  final PictureSelectionFlow? pictureSelectionFlow;

  @override
  State<SharedCreationPictureField> createState() =>
      _SharedCreationPictureFieldState();
}

class _SharedCreationPictureFieldState
    extends State<SharedCreationPictureField> {
  late final PictureSelectionFlow _flow;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _flow = widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
  }

  Future<void> _select(ImageSource source) async {
    if (_processing || !widget.enabled) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    widget.onProcessingChanged(true);
    try {
      final selected = await _flow.selectAndCrop(
        context: context,
        source: source,
      );
      if (!mounted || selected == null) return;
      if (selected.bytes.length > 8 * 1024 * 1024) {
        setState(
          () => _error = sharedText(
            context,
            'Choose a picture smaller than 8 MiB.',
            'Wähle ein Bild mit weniger als 8 MiB.',
          ),
        );
        return;
      }
      widget.onChanged(selected);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.failedToSelectPicture);
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        widget.onProcessingChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResponsivePictureFrame(
        height: 220,
        child: widget.picture == null
            ? Icon(
                Icons.photo_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : Image.memory(
                widget.picture!.bytes,
                key: const Key('shared-creation-picture-preview'),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
      const SizedBox(height: 12),
      PictureSelectionControls(
        enabled: widget.enabled,
        processing: _processing,
        hasPicture: widget.picture != null,
        cameraSupported: _flow.supportsImageSource(ImageSource.camera),
        onSelect: _select,
        onRemove: () {
          setState(() => _error = null);
          widget.onChanged(null);
        },
        actionButtonKey: const Key('shared-creation-picture-select'),
        removeButtonKey: const Key('shared-creation-picture-remove'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      const SizedBox(height: 16),
    ],
  );
}
