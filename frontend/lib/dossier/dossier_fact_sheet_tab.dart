import 'package:flutter/material.dart';

import 'dossier.dart';
import 'dossier_format.dart';

/// Tabblad Feitenlijst: gerenderde weergave, status, bewerken en laten bijwerken.
class FactSheetTab extends StatefulWidget {
  const FactSheetTab({
    required this.factSheet,
    required this.canResearch,
    required this.onSave,
    required this.onRefresh,
    super.key,
  });

  final FactSheet factSheet;
  final bool canResearch;
  final Future<void> Function(String markdown) onSave;
  final Future<void> Function() onRefresh;

  @override
  State<FactSheetTab> createState() => _FactSheetTabState();
}

class _FactSheetTabState extends State<FactSheetTab>
    with AutomaticKeepAliveClientMixin {
  TextEditingController? _editor;
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(
      () => _editor = TextEditingController(text: widget.factSheet.markdown),
    );
  }

  void _cancelEditing() {
    _editor?.dispose();
    setState(() => _editor = null);
  }

  Future<void> _save() async {
    final markdown = _editor?.text;
    if (markdown == null) return;
    setState(() => _saving = true);
    await widget.onSave(markdown);
    if (!mounted) return;
    setState(() => _saving = false);
    _cancelEditing();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sheet = widget.factSheet;
    final editor = _editor;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusLine(sheet: sheet),
            const SizedBox(height: 12),
            if (widget.canResearch && editor == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: sheet.isRunning ? null : _startEditing,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Bewerken'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: sheet.isRunning ? null : widget.onRefresh,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Laten bijwerken'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (editor != null) ...[
              Text(
                'Markdown. Verwijs naar een archiefbron als [naam](hkh:collection/ident).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: editor,
                minLines: 12,
                maxLines: 40,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Feitenlijst',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Opslaan'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saving ? null : _cancelEditing,
                    child: const Text('Annuleren'),
                  ),
                ],
              ),
            ] else if (sheet.markdown.trim().isEmpty)
              const InfoCard(
                icon: Icons.fact_check_outlined,
                text:
                    'De feitenlijst is nog leeg. Na elke beantwoorde vraag vult de AI hier personen, adressen, jaartallen en gebeurtenissen aan, met hun bronnen. Je kunt de lijst ook zelf bewerken.',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: RenderedHtml(sheet.html),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.sheet});
  final FactSheet sheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (sheet.isRunning) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('AI werkt de lijst bij…')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sheet.updatedAt == null
              ? 'Nog niet bijgewerkt'
              : 'Bijgewerkt op ${formatDateTime(sheet.updatedAt!)}'
                    '${sheet.dirty ? ' · er zijn nieuwe antwoorden die nog niet zijn verwerkt' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        if (sheet.isFailed) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sheet.error ?? 'Het bijwerken van de feitenlijst is mislukt.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
