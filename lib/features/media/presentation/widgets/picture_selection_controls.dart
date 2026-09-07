import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations_context.dart';

class PictureSelectionControls extends StatelessWidget {
  static const cameraOptionKey = Key('picture-source-camera-option');
  static const galleryOptionKey = Key('picture-source-gallery-option');

  final bool enabled;
  final bool hasPicture;
  final bool cameraSupported;
  final Future<void> Function(ImageSource source) onSelect;
  final VoidCallback onRemove;
  final Key actionButtonKey;
  final Key removeButtonKey;

  const PictureSelectionControls({
    super.key,
    required this.enabled,
    required this.hasPicture,
    required this.cameraSupported,
    required this.onSelect,
    required this.onRemove,
    required this.actionButtonKey,
    required this.removeButtonKey,
  });

  Future<void> _chooseSource(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  sheetContext.l10n.choosePictureSource,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                key: cameraOptionKey,
                enabled: cameraSupported,
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(sheetContext.l10n.takePhoto),
                subtitle: cameraSupported
                    ? null
                    : Text(sheetContext.l10n.cameraUnavailable),
                onTap: cameraSupported
                    ? () {
                        Navigator.of(sheetContext).pop(ImageSource.camera);
                      }
                    : null,
              ),
              ListTile(
                key: galleryOptionKey,
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(sheetContext.l10n.chooseFromGallery),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await onSelect(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: actionButtonKey,
            onPressed: enabled
                ? () async {
                    await _chooseSource(context);
                  }
                : null,
            icon: Icon(
              hasPicture
                  ? Icons.edit_outlined
                  : Icons.add_photo_alternate_outlined,
            ),
            label: Text(
              hasPicture ? context.l10n.changePicture : context.l10n.addPicture,
            ),
          ),
        ),
        if (hasPicture) ...[
          const SizedBox(width: 8),
          IconButton(
            key: removeButtonKey,
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.removePicture,
          ),
        ],
      ],
    );
  }
}
