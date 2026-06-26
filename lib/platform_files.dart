export 'platform_files_stub.dart'
    if (dart.library.html) 'platform_files_web.dart'
    if (dart.library.io) 'platform_files_io.dart';
