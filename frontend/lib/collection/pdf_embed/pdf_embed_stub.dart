import 'package:flutter/widgets.dart';

/// Op mobiel/desktop hebben we (nog) geen ingesloten PDF-weergave; de aanroepende
/// pagina valt dan terug op "open in nieuwe pagina" / "download".
const bool supportsEmbeddedPdf = false;

Widget buildEmbeddedPdf(String url) => const SizedBox.shrink();
