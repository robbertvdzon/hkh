import 'package:flutter/material.dart';

import 'dossier.dart';
import 'dossier_format.dart';

/// Dialoog "Delen en leden". Iedereen ziet de leden; alleen de eigenaar kan ze wijzigen.
/// Geeft de laatst bekende dossierstand terug als er iets is gewijzigd.
Future<DossierDetail?> showMembersDialog(
  BuildContext context, {
  required DossierSource source,
  required DossierDetail detail,
}) {
  return showDialog<DossierDetail>(
    context: context,
    builder: (_) => _MembersDialog(source: source, initial: detail),
  );
}

class _MembersDialog extends StatefulWidget {
  const _MembersDialog({required this.source, required this.initial});

  final DossierSource source;
  final DossierDetail initial;

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  late DossierDetail _detail = widget.initial;
  final _email = TextEditingController();
  DossierRole _newRole = DossierRole.researcher;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<DossierDetail?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        if (updated != null) _detail = updated;
        _changed = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _busy = false;
      });
    }
  }

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Vul een geldig e-mailadres in.');
      return;
    }
    await _run(() async {
      final updated = await widget.source.setMember(
        _detail.id,
        email,
        _newRole,
      );
      _email.clear();
      return updated;
    });
  }

  Future<void> _setRole(Member member, DossierRole role) =>
      _run(() => widget.source.setMember(_detail.id, member.email, role));

  Future<void> _remove(Member member) => _run(() async {
    await widget.source.removeMember(_detail.id, member.email);
    return widget.source.loadDossier(_detail.id);
  });

  @override
  Widget build(BuildContext context) {
    final canManage = _detail.role.canManage;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Delen en leden'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: Text(_detail.ownerEmail),
              subtitle: const Text('Eigenaar'),
            ),
            for (final member in _detail.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(member.email),
                subtitle: canManage ? null : Text(member.role.label),
                trailing: canManage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<DossierRole>(
                            value: member.role,
                            underline: const SizedBox.shrink(),
                            onChanged: _busy
                                ? null
                                : (role) {
                                    if (role != null && role != member.role) {
                                      _setRole(member, role);
                                    }
                                  },
                            items: [
                              for (final role in DossierRole.assignable)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(role.label),
                                ),
                            ],
                          ),
                          IconButton(
                            onPressed: _busy ? null : () => _remove(member),
                            icon: const Icon(Icons.person_remove_outlined),
                            tooltip: 'Lid verwijderen',
                          ),
                        ],
                      )
                    : null,
              ),
            if (_detail.members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Dit dossier is nog niet gedeeld.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (canManage) ...[
              const Divider(height: 24),
              Text('Lid toevoegen', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  labelText: 'E-mailadres',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DossierRole>(
                      initialValue: _newRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final role in DossierRole.assignable)
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                      ],
                      onChanged: (role) {
                        if (role != null) setState(() => _newRole = role);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _add,
                    child: const Text('Toevoegen'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Lezer: alleen meelezen. Onderzoeker: ook vragen stellen en de feitenlijst laten bijwerken. '
                'Bewerker: ook artikelen schrijven en AI-voorstellen beoordelen. '
                'Iemand die nog nooit heeft ingelogd, ziet het dossier na de eerste login.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _changed ? _detail : null),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }
}
