import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_style.dart';
import 'ai_search.dart';
import 'answer_sharing.dart';

Future<void> showAnswerShareDialog(
  BuildContext context,
  AiAnswerShareSource source,
  AiSearchTurn answer,
) => showDialog<void>(
  context: context,
  builder: (_) => AnswerShareDialog(source: source, answer: answer),
);

class AnswerShareDialog extends StatefulWidget {
  const AnswerShareDialog({
    required this.source,
    required this.answer,
    super.key,
  });
  final AiAnswerShareSource source;
  final AiSearchTurn answer;
  @override
  State<AnswerShareDialog> createState() => _AnswerShareDialogState();
}

class _AnswerShareDialogState extends State<AnswerShareDialog> {
  bool _busy = true;
  bool _loaded = false;
  bool _copied = false;
  String? _token;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _run(() async {
    _token = await widget.source.answerShareToken(widget.answer.id);
    _loaded = true;
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _copied = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Dit lukte niet. Probeer het nog eens.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: sharedAnswerUrl(_token!)));
      if (mounted) {
        setState(() {
          _copied = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Kopiëren lukte niet. Je kunt de link hierboven selecteren en kopiëren.',
        );
      }
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${widget.answer.title ?? 'Een antwoord uit het HKH-archief'}\n${sharedAnswerUrl(_token!)}',
          subject:
              widget.answer.title ?? 'Gedeeld antwoord uit het HKH-archief',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
          downloadFallbackEnabled: false,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Delen via deze browser is niet beschikbaar. Gebruik Kopieer link.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Antwoord delen',
    maxWidth: 520,
    content: SizedBox(
      width: appDialogContentWidth(context, maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.answer.title ?? widget.answer.question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: appGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Iedereen met de link kan deze vraag en dit antwoord lezen, inclusief afbeeldingen en bronnen. Inloggen is niet nodig.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Je deelt alleen dit antwoord. Vervolgvragen en andere zoekopdrachten blijven privé. Je kunt de link hier later intrekken.',
          ),
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (!_loaded)
            OutlinedButton(
              onPressed: _load,
              child: const Text('Opnieuw proberen'),
            )
          else if (_token == null) ...[
            if (_message != null) ...[
              Text(_message!),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => _run(() async {
                _token = await widget.source.shareAnswer(widget.answer.id);
                _message = null;
              }),
              icon: const Icon(Icons.link),
              label: const Text('Maak deelbare link'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: appCardBorder),
              ),
              child: SelectableText(sharedAnswerUrl(_token!)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _copy,
                  icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                  label: Text(_copied ? 'Link gekopieerd' : 'Kopieer link'),
                ),
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Delen via…'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _run(() async {
                  await widget.source.revokeAnswerShare(widget.answer.id);
                  _token = null;
                  _message =
                      'De link is ingetrokken. Mensen met de oude link kunnen dit antwoord niet meer openen.';
                }),
                icon: const Icon(Icons.link_off),
                label: const Text('Delen stoppen'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: appErrorForeground)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Sluiten'),
      ),
    ],
  );
}
