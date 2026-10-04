import 'package:flutter/material.dart';

import '../theme/app_style.dart';

class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: appDisclaimerBackground,
      border: Border.all(color: appDisclaimerBorder),
      borderRadius: BorderRadius.circular(appCardRadius),
    ),
    child: SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Korte disclaimer:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: appDisclaimerForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'De antwoorden zijn door AI samengesteld op basis van informatie uit het HKH-archief. '
            'AI probeert deze informatie te interpreteren en verbanden te leggen, maar kan daarbij '
            'fouten maken of onjuiste conclusies trekken. We kunnen daarom niet garanderen dat de '
            'antwoorden juist en volledig zijn. Raadpleeg bij twijfel de oorspronkelijke bronnen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: appDisclaimerForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
