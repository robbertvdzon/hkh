import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/admin_session.dart';
import 'admin_ai_capacity.dart';
import 'capacity_image/capacity_image.dart';

/// Read-only rendering of the stored answer, using the same HTML engine as the public site.
class AdminAiCapacityResultPage extends StatefulWidget {
  const AdminAiCapacityResultPage({
    required this.identity,
    required this.source,
    required this.campaignId,
    required this.runId,
    super.key,
  });
  final AdminIdentity identity;
  final AdminAiCapacitySource source;
  final String campaignId;
  final String runId;

  @override
  State<AdminAiCapacityResultPage> createState() =>
      _AdminAiCapacityResultPageState();
}

class _AdminAiCapacityResultPageState extends State<AdminAiCapacityResultPage> {
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      final status = (_result?['run'] as Map<String, dynamic>?)?['status'];
      if (!['SUCCEEDED', 'FAILED', 'CANCELLED'].contains(status)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final result = await widget.source.result(
        widget.identity,
        widget.campaignId,
        widget.runId,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Het testresultaat kon niet worden geladen.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final run = result?['run'] as Map<String, dynamic>?;
    final turns = (result?['turns'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final execution =
        (run?['config'] as Map<String, dynamic>?)?['execution']
            as Map<String, dynamic>?;
    final question = (run?['question'] as Map<String, dynamic>?)?['question'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Testresultaat',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Verversen',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Opnieuw proberen'),
          ),
        ],
        if (_loading && result == null) const LinearProgressIndicator(),
        if (run != null) ...[
          Text(
            '${run['campaign_name']} · zoekopdracht ${run['ordinal']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (execution != null)
            Text(
              '${execution['vendorId']} · ${execution['model']} · ${execution['mode']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          SelectableText(
            '$question',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          for (final turn in turns) _turn(context, turn),
          if (turns.isEmpty)
            const Text('Deze zoekopdracht heeft nog geen antwoord.'),
        ],
      ],
    );
  }

  Widget _turn(BuildContext context, Map<String, dynamic> turn) {
    final html = turn['answerHtml'] as String?;
    final sources = turn['sourcesHtml'] as String?;
    final succeeded = turn['status'] == 'SUCCEEDED';
    final expanded = turn['expandsTurnId'] != null;
    final label = expanded
        ? 'Volledige uitwerking'
        : (turn['turnNumber'] as num? ?? 1) > 1
        ? 'Vervolgvraag'
        : 'Antwoord';
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded || (turn['turnNumber'] as num? ?? 1) > 1) ...[
            const Divider(height: 32),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            if (!expanded)
              SelectableText(
                '${turn['question']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
          ],
          if (!succeeded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                turn['status'] == 'FAILED'
                    ? 'Het onderzoek is mislukt. ${turn['errorMessage'] ?? ''}'
                    : turn['status'] == 'CANCELLED'
                    ? 'Het onderzoek is gestopt.'
                    : 'Het onderzoek loopt nog. Het antwoord verschijnt hier zodra het klaar is.',
              ),
            ),
          if (succeeded && html?.trim().isNotEmpty == true) ...[
            if (turn['title'] != null)
              Text(
                '${turn['title']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 16),
            SelectionArea(child: CapacityAnswerHtml(html!)),
            if (sources?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Bronnen bekijken'),
                children: [SelectionArea(child: CapacityAnswerHtml(sources!))],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class CapacityAnswerHtml extends StatelessWidget {
  const CapacityAnswerHtml(this.html, {super.key});
  final String html;

  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
    customStylesBuilder: (element) => switch (element.localName) {
      'figure' => {'margin': '24px 0'},
      'figcaption' => {
        'font-size': '14px',
        'color': '#5c5960',
        'margin-top': '8px',
      },
      'blockquote' => {
        'border-left': '3px solid #b7a8cf',
        'padding-left': '16px',
      },
      _ => null,
    },
    customWidgetBuilder: (element) {
      if (element.localName != 'img') return null;
      final url = element.attributes['src'];
      if (url == null || !_webUrl(url)) return const SizedBox.shrink();
      final caption = element.attributes['alt'] ?? 'Archieffoto';
      return LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            height:
                ((constraints.maxWidth.isFinite ? constraints.maxWidth : 640) *
                        0.72)
                    .clamp(220.0, 520.0),
            child: Tooltip(
              message: 'Foto vergroten',
              child: InkWell(
                onTap: () => _zoom(context, url, caption),
                mouseCursor: SystemMouseCursors.zoomIn,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: buildNetworkImage(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      );
    },
    onTapUrl: (url) async {
      if (!_webUrl(url)) return false;
      return launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    },
  );

  static bool _webUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  Future<void> _zoom(BuildContext context, String url, String caption) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Foto sluiten',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(caption),
            ),
            body: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              child: SizedBox.expand(
                child: buildNetworkImage(url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
}
