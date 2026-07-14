import 'dart:io';

import 'package:crypto/crypto.dart';

class SegmentFileMetadata {
  const SegmentFileMetadata({required this.size, required this.sha256});

  final int size;
  final String sha256;
}

Future<SegmentFileMetadata> inspectSegmentFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('segment_file_missing');
  }
  final size = await file.length();
  if (size <= 0) {
    throw StateError('segment_file_empty');
  }
  final digest = await sha256.bind(file.openRead()).first;
  return SegmentFileMetadata(size: size, sha256: digest.toString());
}
