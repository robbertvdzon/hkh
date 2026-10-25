import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../shell/admin_router.dart';

class CapacityResultLink extends StatelessWidget {
  const CapacityResultLink({
    required this.campaignId,
    required this.runId,
    super.key,
  });

  final String campaignId, runId;

  @override
  Widget build(BuildContext context) => Link(
    uri: Uri.base.replace(
      fragment: AdminPaths.capacityResult(campaignId, runId),
    ),
    target: LinkTarget.blank,
    builder: (context, followLink) => TextButton.icon(
      onPressed: followLink,
      icon: const Icon(Icons.open_in_new),
      label: const Text('Resultaat bekijken'),
    ),
  );
}
