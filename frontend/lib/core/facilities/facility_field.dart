import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../design/design.dart';
import 'facility_repository.dart';

/// Saisie d'un établissement avec suggestions : choisir un nom existant évite
/// de créer un doublon (et de se retrouver seul dans un « nouvel » établissement).
class FacilityField extends StatefulWidget {
  const FacilityField({
    super.key,
    required this.controller,
    required this.apiClient,
    this.label = 'Établissement de santé',
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final ApiClient apiClient;
  final String label;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  State<FacilityField> createState() => _FacilityFieldState();
}

class _FacilityFieldState extends State<FacilityField> {
  final _focus = FocusNode();
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    FacilityRepository(widget.apiClient).list().then((facilities) {
      if (mounted) setState(() => _names = facilities.map((f) => f.name).toList());
    }).catchError((_) {
      // Pas de réseau : saisie libre, sans suggestions.
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  static String _plain(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final query = _plain(value.text.trim());
        if (query.isEmpty) return _names;
        return _names.where((name) => _plain(name).contains(query));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.local_hospital_outlined),
        ),
        validator: widget.validator,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 3,
          borderRadius: KRadius.controlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final name in options)
                  ListTile(
                    leading: const Icon(Icons.local_hospital_outlined),
                    title: Text(name),
                    onTap: () => onSelected(name),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
