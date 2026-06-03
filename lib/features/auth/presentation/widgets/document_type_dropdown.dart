import 'package:flutter/material.dart';
import '../../../../core/constants/document_type.dart';
import '../../../../core/theme/app_colors.dart';

class DocumentTypeDropdown extends StatelessWidget {
  const DocumentTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DocumentType? value;
  final ValueChanged<DocumentType?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DocumentType>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? 'Selecciona el tipo de documento.' : null,
      decoration: const InputDecoration(
        labelText: 'Tipo de documento',
        prefixIcon: Icon(Icons.badge_outlined, size: 20),
      ),
      items: DocumentType.values
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type.label, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
      dropdownColor: AppColors.neutralWhite,
      isExpanded: true,
    );
  }
}
