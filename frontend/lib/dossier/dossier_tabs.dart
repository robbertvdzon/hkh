import 'package:flutter/material.dart';
import '../theme/app_style.dart';

/// Dezelfde dossiernavigatie op het overzicht en binnen een artikel.
class DossierTabs extends StatelessWidget implements PreferredSizeWidget {
  const DossierTabs({required this.controller, this.onTap, super.key});
  final TabController controller;
  final ValueChanged<int>? onTap;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isNarrowLayout(context) ? 16 : 24,
            0,
            isNarrowLayout(context) ? 16 : 24,
            12,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: controller,
              onTap: onTap,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: appGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: appGreen,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: [
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrowLayout(context)) ...[
                        const Icon(Icons.question_answer_outlined, size: 18),
                        const SizedBox(width: 8),
                      ],
                      const Text('Vragen'),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrowLayout(context)) ...[
                        const Icon(Icons.fact_check_outlined, size: 18),
                        const SizedBox(width: 8),
                      ],
                      const Text('Feitenlijst'),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrowLayout(context)) ...[
                        const Icon(Icons.article_outlined, size: 18),
                        const SizedBox(width: 8),
                      ],
                      const Text('Artikelen'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
