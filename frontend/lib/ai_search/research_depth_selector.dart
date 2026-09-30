import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'ai_search.dart';

/// Keuze hoe diep de digitale onderzoeker zoekt: Snel (1 ronde, standaard),
/// Doorzoeken (max 5 rondes) of Uitgebreid (max 15 rondes). Als keuzechips,
/// zodat de rij op smalle schermen netjes doorloopt.
class ResearchDepthSelector extends StatelessWidget {
  const ResearchDepthSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final AiResearchDepth value;
  final ValueChanged<AiResearchDepth> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const Key('research-depth'),
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text('Onderzoek:', style: TextStyle(color: appMutedText)),
      for (final depth in AiResearchDepth.values)
        Tooltip(
          message: depth.description,
          child: ChoiceChip(
            key: Key('research-depth-${depth.name}'),
            label: Text(depth.label),
            selected: value == depth,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: enabled ? (_) => onChanged(depth) : null,
          ),
        ),
    ],
  );
}

/// Compacte variant voor de vervolgvraagbalk: één knop met de huidige diepte
/// die een menu met de drie opties opent, zodat de balk één regel hoog blijft.
class ResearchDepthMenuButton extends StatelessWidget {
  const ResearchDepthMenuButton({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final AiResearchDepth value;
  final ValueChanged<AiResearchDepth> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AiResearchDepth>(
    key: const Key('research-depth-menu'),
    enabled: enabled,
    tooltip: 'Onderzoeksdiepte: ${value.description}',
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (context) => [
      for (final depth in AiResearchDepth.values)
        PopupMenuItem(
          value: depth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(depth.label),
              Text(
                depth.description,
                style: const TextStyle(color: appMutedText, fontSize: 12),
              ),
            ],
          ),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.manage_search, size: 18),
          const SizedBox(width: 4),
          Text(value.label),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    ),
  );
}
