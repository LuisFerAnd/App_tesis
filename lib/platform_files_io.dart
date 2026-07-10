import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> createRecordingPath(String fileName) async {
  final directory = await _sanareDirectory('audio/autosave');
  return '${directory.path}/$fileName';
}

Future<String> savePdfBytes(String fileName, List<int> bytes) async {
  final directory = await _sanareDirectory('pdf');
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> saveCsvBytes(String fileName, List<int> bytes) async {
  final directory = await _sanareDirectory('csv');
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> saveExportBytes(String fileName, List<int> bytes) async {
  final directory = await _sanareDirectory('exports');
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory> _sanareDirectory(String child) async {
  final base = await getApplicationDocumentsDirectory();
  final directory = Directory('${base.path}/Sanare/$child');

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  return directory;
}
