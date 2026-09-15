import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Android en andere niet-webplatformen: schrijf de bytes naar een tijdelijk
/// bestand en open daarvoor de deel-/opslagdialoog van het systeem. Er zijn
/// geen extra Android-permissies nodig; de tijdelijke map is app-eigen.
Future<void> saveAnswerPdf(String fileName, Uint8List bytes) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
    ),
  );
}
