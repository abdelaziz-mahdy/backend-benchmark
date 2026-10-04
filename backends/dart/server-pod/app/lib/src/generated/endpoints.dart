/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:benchmark_server/src/generated/note.dart' as _ixox1gdy;
import 'package:serverpod/serverpod.dart' as _is;

import '../endpoints/note_endpoint.dart' as _i4n3t746;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'note': _i4n3t746.NoteEndpoint()..initialize(server, 'note', null),
    };
    connectors['note'] = _is.EndpointConnector(
      name: 'note',
      endpoint: endpoints['note']!,
      methodConnectors: {
        'createNote': _is.MethodConnector(
          name: 'createNote',
          params: {
            'note': _is.ParameterDescription(
              name: 'note',
              type: _is.getType<_ixox1gdy.Note>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['note'] as _i4n3t746.NoteEndpoint).createNote(
                session,
                params['note'],
              ),
        ),
        'getNotes': _is.MethodConnector(
          name: 'getNotes',
          params: {
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['note'] as _i4n3t746.NoteEndpoint).getNotes(
                session,
                params['limit'],
                params['offset'],
              ),
        ),
        'getNote': _is.MethodConnector(
          name: 'getNote',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['note'] as _i4n3t746.NoteEndpoint).getNote(
                session,
                params['id'],
              ),
        ),
        'noDbEndpoint': _is.MethodConnector(
          name: 'noDbEndpoint',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['note'] as _i4n3t746.NoteEndpoint).noDbEndpoint(
                session,
              ),
        ),
      },
    );
  }
}
