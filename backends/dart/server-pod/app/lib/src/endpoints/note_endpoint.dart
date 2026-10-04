import 'package:benchmark_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// Benchmark API as Serverpod RPC methods (POST /note/<method>), which is how
/// Serverpod apps are normally called. The k6 scenarios map the shared
/// operations onto these methods (api_style: serverpod_rpc in backend.yaml).
class NoteEndpoint extends Endpoint {
  Future<Note> createNote(Session session, Note note) async {
    return Note.db.insertRow(session, note);
  }

  Future<List<Note>> getNotes(Session session, int limit, int offset) async {
    return Note.db.find(
      session,
      orderBy: (t) => t.id,
      limit: limit < 0 ? 20 : limit,
      offset: offset < 0 ? 0 : offset,
    );
  }

  Future<Note?> getNote(Session session, int id) async {
    return Note.db.findById(session, id);
  }

  Future<Map<String, String>> noDbEndpoint(Session session) async {
    return {'message': 'No db endpoint'};
  }
}
