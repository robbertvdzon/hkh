import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'ai_search.dart';

/// Keuze hoe diep de digitale onderzoeker zoekt: Snel (1 ronde, standaard),
/// Doorzoeken (max 5 rondes) of Uitgebreid (max 15 rondes). Eén afgeronde
/// stappenbalk, daaronder één zin die met de keuze meeverandert en drie
/// balkjes voor de grondigheid.
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
  Widget build(BuildContext context) => Container(
    key: const Key('research-depth'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: appCardBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Op smalle schermen (of bij grote tekst) komt het label boven de balk
        // en vervalt het woord naast de balkjes.
        final narrow = constraints.maxWidth < 360;
        const label = Text(
          'Onderzoek',
          style: TextStyle(fontWeight: FontWeight.w600, color: appGreen),
        );
        final steps = _DepthSteps(
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [label, const SizedBox(height: 8), steps],
              )
            else
              Row(
                children: [
                  label,
                  const SizedBox(width: 14),
                  Expanded(child: steps),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.schedule, size: 18, color: appGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    key: const Key('research-depth-description'),
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${value.label}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: appGreen,
                          ),
                        ),
                        TextSpan(text: value.explanation),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, color: appMutedText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var step = 1; step <= 3; step++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: step <= value.level ? appGreen : appCardBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (!narrow) ...[
                  const SizedBox(width: 2),
                  const Text(
                    'grondigheid',
                    style: TextStyle(fontSize: 12, color: appMutedText),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// Afgeronde balk met drie gelijke segmenten; het gekozen segment is gevuld.
class _DepthSteps extends StatelessWidget {
  const _DepthSteps({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final AiResearchDepth value;
  final bool enabled;
  final ValueChanged<AiResearchDepth> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      border: Border.all(color: appGreen),
      borderRadius: BorderRadius.circular(999),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        for (final depth in AiResearchDepth.values) ...[
          if (depth != AiResearchDepth.values.first)
            const VerticalDivider(width: 1, thickness: 1, color: appGreen),
          Expanded(
            child: Semantics(
              button: true,
              selected: value == depth,
              label: '${depth.label}: ${depth.description}',
              child: Tooltip(
                message: depth.description,
                child: Material(
                  color: value == depth ? appGreen : Colors.white,
                  child: InkWell(
                    key: Key('research-depth-${depth.name}'),
                    onTap: enabled ? () => onChanged(depth) : null,
                    child: Center(
                      child: Text(
                        depth.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: value == depth
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: value == depth ? Colors.white : appGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Compacte variant voor de vervolgvraagbalk: een pil met de huidige diepte
/// en duur die een menu met de drie opties opent, zodat de balk één regel
/// hoog blijft.
class ResearchDepthMenuButton extends StatelessWidget {
  const ResearchDepthMenuButton({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
    super.key,
  });

  final AiResearchDepth value;
  final ValueChanged<AiResearchDepth> onChanged;
  final bool enabled;

  /// Alleen de naam, zonder duur, voor smalle schermen.
  final bool compact;

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
          child: SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        depth.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      depth.duration,
                      style: const TextStyle(color: appMutedText),
                    ),
                  ],
                ),
                Text(
                  depth.explanation,
                  softWrap: true,
                  style: const TextStyle(color: appMutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
    ],
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? appAccentBackground : appBackground,
        border: Border.all(color: appGreen),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 16, color: appGreen),
          const SizedBox(width: 6),
          Text(
            compact ? value.label : '${value.label} · ${value.duration}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appGreen,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18, color: appGreen),
        ],
      ),
    ),
  );
}
