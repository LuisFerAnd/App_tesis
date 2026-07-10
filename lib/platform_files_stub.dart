Future<String> createRecordingPath(String fileName) async => '';

Future<String> savePdfBytes(String fileName, List<int> bytes) {
  throw UnsupportedError('El guardado local de PDF esta disponible en movil.');
}

Future<String> saveCsvBytes(String fileName, List<int> bytes) {
  throw UnsupportedError('El guardado local de CSV esta disponible en movil.');
}

Future<String> saveExportBytes(String fileName, List<int> bytes) {
  throw UnsupportedError('La exportación local está disponible en móvil.');
}
