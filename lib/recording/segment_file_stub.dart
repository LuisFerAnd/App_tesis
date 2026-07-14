class SegmentFileMetadata {
  const SegmentFileMetadata({required this.size, required this.sha256});

  final int size;
  final String sha256;
}

Future<SegmentFileMetadata> inspectSegmentFile(String path) =>
    throw UnsupportedError(
      'El almacenamiento de segmentos no está disponible.',
    );
