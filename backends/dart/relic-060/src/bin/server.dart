import 'dart:io';
import 'package:relic/relic.dart';
import 'package:relic/io_adapter.dart';

void main() async {
  await serve(
    (ctx) async {
      final request = ctx.request;
      final path = request.requestedUri.path;

      if (path == '/no_db_endpoint/' || path == '/no_db_endpoint2/') {
        return ctx.respond(Response.ok(
          body: Body.fromString('no db endpoint'),
        ));
      }

      if (path == '/notes/' && request.method == Method.post) {
        return ctx.respond(Response.ok(
          body: Body.fromString('{"id": 1}'),
        ));
      }

      if (path == '/notes/' && request.method == Method.get) {
        return ctx.respond(Response.ok(
          body: Body.fromString('[]'),
        ));
      }

      if (path == '/') {
        return ctx.respond(Response.ok(
          body: Body.fromString('ok'),
        ));
      }

      return ctx.respond(Response.notFound());
    },
    InternetAddress.anyIPv6,
    8000,
  );
  print('Relic 0.6.0 server running on port 8000');
}
