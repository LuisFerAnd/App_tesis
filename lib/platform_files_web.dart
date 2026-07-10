// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

Future<String> createRecordingPath(String fileName) async => '';

Future<String> savePdfBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
  return _downloadBlob(fileName, blob);
}

Future<String> saveCsvBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'text/csv');
  return _downloadBlob(fileName, blob);
}

Future<String> saveExportBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([
    Uint8List.fromList(bytes),
  ], 'application/octet-stream');
  return _downloadBlob(fileName, blob);
}

String _downloadBlob(String fileName, html.Blob blob) {
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return fileName;
}
