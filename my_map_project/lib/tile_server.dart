import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

Future<void> startLocalTileServer() async {
  final handler = createStaticHandler(
    'C:/combined_tiles',
    listDirectories: true,
  );
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    8081,
  );
  print('✅ Tile server running at http://${server.address.address}:${server.port}');
}
