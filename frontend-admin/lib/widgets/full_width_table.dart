import 'package:flutter/material.dart';

/// Opent een tabel in een schermvullend venster over de volle breedte, met
/// zichtbare horizontale en verticale scrollbalken. De tabel in het blok zelf
/// blijft als beknopt overzicht staan.
Future<void> showFullWidthTable(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context) tableBuilder,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: _FullWidthTable(title: title, tableBuilder: tableBuilder),
  ),
);

class _FullWidthTable extends StatefulWidget {
  const _FullWidthTable({required this.title, required this.tableBuilder});

  final String title;
  final Widget Function(BuildContext context) tableBuilder;

  @override
  State<_FullWidthTable> createState() => _FullWidthTableState();
}

class _FullWidthTableState extends State<_FullWidthTable> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      leading: IconButton(
        key: const Key('full-width-table-close'),
        tooltip: 'Sluiten',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertical,
        child: Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: widget.tableBuilder(context),
          ),
        ),
      ),
    ),
  );
}
