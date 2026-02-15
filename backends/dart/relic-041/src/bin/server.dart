import 'dart:io';
import 'package:relic/relic.dart';
import 'package:relic/io_adapter.dart';

void main() async {
  await serve(
    (ctx) async {
      final request = ctx.request;
      final path = request.requestedUri.path;

      if (path == '/no_db_endpoint/' || path == '/no_db_endpoint2/') {
        return ctx.withResponse(Response.ok(
          body: Body.fromString('no db endpoint'),
        ));
      }

      if (path == '/notes/' && request.method == RequestMethod.post) {
        return ctx.withResponse(Response.ok(
          body: Body.fromString('{"id": 1}'),
        ));
      }

      if (path == '/notes/' && request.method == RequestMethod.get) {
        return ctx.withResponse(Response.ok(
          body: Body.fromString('[]'),
        ));
      }

      if (path == '/') {
        return ctx.withResponse(Response.ok(
          body: Body.fromString('ok'),
        ));
      }

      return ctx.withResponse(Response.notFound());
    },
    InternetAddress.anyIPv6,
    8000,
  );
  print('Relic 0.4.1 server running on port 8000');
}
