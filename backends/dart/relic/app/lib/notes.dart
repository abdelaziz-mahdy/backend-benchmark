import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

String _env(String key, String fallback) {
  final v = Platform.environment[key];
  return v == null || v.isEmpty ? fallback : v;
}

/// How many isolates serve requests: one per core given to the app.
int get isolates => int.tryParse(_env('BENCH_CPUS', '2')) ?? 2;

// Top-level fields are per isolate, so each serving isolate opens its own
// pool on first use. 20 connections are split across the isolates, like the
// other multi-worker backends (10 per worker, 20 in total).
final Pool<void> _pool = Pool.withEndpoints(
  [
    Endpoint(
      host: _env('DATABASE_HOST', 'db'),
      port: int.parse(_env('DATABASE_PORT', '5432')),
      database: _env('DATABASE_NAME', 'postgres'),
      username: _env('DATABASE_USER', 'postgres'),
      password: _env('DATABASE_PASSWORD', 'postgres'),
    ),
  ],
  settings: PoolSettings(
    maxConnectionCount: (20 / isolates).ceil(),
    sslMode: SslMode.disable,
  ),
);

bool _migrated = false;

Response _json(Object? value, [int status = 200]) => Response(
  status,
  body: Body.fromString(jsonEncode(value), mimeType: MimeType.json),
);

Response _text(String text, int status) =>
    Response(status, body: Body.fromString(text));

int _queryInt(Request req, String key, int fallback) {
  final v = int.tryParse(req.url.queryParameters[key] ?? '');
  return v != null && v >= 0 ? v : fallback;
}

Map<String, Object?> _note(ResultRow r) => {
  'id': r[0],
  'title': r[1],
  'content': r[2],
};

Future<Response> _health(Request req) async {
  if (!_migrated) {
    try {
      await _pool.execute(File('migration.sql').readAsStringSync());
    } catch (e) {
      return _text('not ready: $e', 503);
    }
    _migrated = true;
  }
  return _text('ok', 200);
}

Response _noDb(Request req) => _json({'message': 'No db endpoint'});

Future<Response> _listNotes(Request req) async {
  final rows = await _pool.execute(
    r'SELECT id, title, content FROM note ORDER BY id LIMIT $1 OFFSET $2',
    parameters: [_queryInt(req, 'limit', 20), _queryInt(req, 'offset', 0)],
  );
  return _json([for (final r in rows) _note(r)]);
}

Future<Response> _createNote(Request req) async {
  final Object? body;
  try {
    body = jsonDecode(await req.readAsString());
  } on FormatException catch (e) {
    return _text(e.message, 400);
  }
  if (body is! Map || body['title'] is! String || body['content'] is! String) {
    return _text('title and content are required', 400);
  }
  final rows = await _pool.execute(
    r'INSERT INTO note (title, content) VALUES ($1, $2) RETURNING id',
    parameters: [body['title'], body['content']],
  );
  return _json({
    'id': rows.first[0],
    'title': body['title'],
    'content': body['content'],
  }, 201);
}

Future<Response> _getNote(Request req) async {
  final id = int.tryParse(req.rawPathParameters[#id] ?? '');
  if (id == null) return _text('not found', 404);
  final rows = await _pool.execute(
    r'SELECT id, title, content FROM note WHERE id = $1',
    parameters: [id],
  );
  if (rows.isEmpty) return _text('not found', 404);
  return _json(_note(rows.first));
}

/// The API contract every backend serves (see CLAUDE.md).
RelicApp buildApp() => RelicApp()
  ..get('/health', _health)
  ..get('/no_db_endpoint/', _noDb)
  ..get('/notes/', _listNotes)
  ..post('/notes/', _createNote)
  ..get('/notes/:id', _getNote);
