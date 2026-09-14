import 'package:flutter/material.dart';

import '../theme/app_style.dart';
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
    // Bij weinig ruimte komen de rolkeuze en de verwijderactie van een lid op
    // een eigen regel onder het e-mailadres. De dialooginhoud is even breed als
    // AppDialog hem maakt; een LayoutBuilder kan hier niet omdat de dialoog
    // intrinsieke afmetingen opvraagt.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final stacked = appDialogContentWidth(context, maxWidth: 520) < 360 * scale;
    return AppDialog(
      title: 'Delen en leden',
      maxWidth: 520,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PersonRow(
            icon: Icons.star_outline,
            email: _detail.ownerEmail,
            caption: 'Eigenaar',
          ),
          for (final member in _detail.members)
            _MemberRow(
              member: member,
              canManage: canManage,
              busy: _busy,
              stacked: stacked,
              onRoleChanged: (role) => _setRole(member, role),
              onRemove: () => _remove(member),
            ),
          if (_detail.members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Dit dossier is nog niet gedeeld.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: appMutedText),
              ),
            ),
          if (canManage) ...[
            const SizedBox(height: appSectionGap),
            const Divider(height: 1),
            const SizedBox(height: appSectionGap),
            _buildAddSection(context, stacked),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: appErrorForeground),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _changed ? _detail : null),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }

  Widget _buildAddSection(BuildContext context, bool stacked) {
    final theme = Theme.of(context);
    final roleField = DropdownButtonFormField<DossierRole>(
      key: const Key('new-member-role'),
      initialValue: _newRole,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Rol'),
      items: [
        for (final role in DossierRole.assignable)
          DropdownMenuItem(value: role, child: Text(role.label)),
      ],
      onChanged: (role) {
        if (role != null) setState(() => _newRole = role);
      },
    );
    final addButton = FilledButton(
      key: const Key('add-member-button'),
      onPressed: _busy ? null : _add,
      child: const Text('Toevoegen'),
    );
    return Column(
      key: const Key('add-member-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Lid toevoegen',
          style: theme.textTheme.titleSmall?.copyWith(
            color: appGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('new-member-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onSubmitted: (_) => _add(),
          decoration: const InputDecoration(
            labelText: 'E-mailadres',
            hintText: 'naam@voorbeeld.nl',
          ),
        ),
        const SizedBox(height: 12),
        if (stacked) ...[
          roleField,
          const SizedBox(height: 12),
          addButton,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: roleField),
              const SizedBox(width: 12),
              addButton,
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Lezer: alleen meelezen. Onderzoeker: ook vragen stellen en de feitenlijst laten bijwerken. '
          'Bewerker: ook artikelen schrijven en AI-voorstellen beoordelen. '
          'Iemand die nog nooit heeft ingelogd, ziet het dossier na de eerste login.',
          style: theme.textTheme.bodySmall?.copyWith(color: appMutedText),
        ),
      ],
    );
  }
}

/// Eén regel met een persoon: icoon, e-mailadres met ellipsis en een onderschrift.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.icon,
    required this.email,
    this.caption,
    this.trailing,
    this.belowEmail,
    super.key,
  });

  final IconData icon;
  final String email;
  final String? caption;
  final Widget? trailing;
  final Widget? belowEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: appGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: appGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appMutedText,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (belowEmail != null) ...[const SizedBox(height: 8), belowEmail!],
        ],
      ),
    );
  }
}

/// Lid met, voor de eigenaar, een rolkeuze en een verwijderactie.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.busy,
    required this.stacked,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final Member member;
  final bool canManage;
  final bool busy;
  final bool stacked;
  final ValueChanged<DossierRole> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!canManage) {
      return _PersonRow(
        key: Key('member-${member.email}'),
        icon: Icons.person_outline,
        email: member.email,
        caption: member.role.label,
      );
    }
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: DropdownButton<DossierRole>(
            key: Key('member-role-${member.email}'),
            value: member.role,
            isExpanded: stacked,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(appControlRadius),
            onChanged: busy
                ? null
                : (role) {
                    if (role != null && role != member.role) {
                      onRoleChanged(role);
                    }
                  },
            items: [
              for (final role in DossierRole.assignable)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
          ),
        ),
        IconButton(
          key: Key('member-remove-${member.email}'),
          onPressed: busy ? null : onRemove,
          icon: const Icon(Icons.person_remove_outlined),
          tooltip: 'Lid verwijderen',
        ),
      ],
    );
    return _PersonRow(
      key: Key('member-${member.email}'),
      icon: Icons.person_outline,
      email: member.email,
      trailing: stacked ? null : actions,
      belowEmail: stacked ? actions : null,
    );
  }
}
