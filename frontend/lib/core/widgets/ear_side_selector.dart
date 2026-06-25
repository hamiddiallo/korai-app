import 'package:flutter/material.dart';

import '../domain/korai_enums.dart';

class EarSideSelector extends StatelessWidget {
  const EarSideSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EarSide value;
  final ValueChanged<EarSide> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Oreille concernée',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<EarSide>(
          segments: const [
            ButtonSegment(
                value: EarSide.left,
                label: Text('Gauche'),
                icon: Icon(Icons.hearing)),
            ButtonSegment(
                value: EarSide.right,
                label: Text('Droite'),
                icon: Icon(Icons.hearing)),
          ],
          // Une ancienne consultation en « both » n'a aucune option : on
          // n'affiche aucune sélection (et on invite à choisir une oreille)
          // plutôt que de faire échouer le SegmentedButton.
          emptySelectionAllowed: true,
          selected: value == EarSide.both ? <EarSide>{} : {value},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
        ),
      ],
    );
  }
}
