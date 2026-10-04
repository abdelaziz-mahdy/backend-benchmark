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
import 'dart:async' as _ida;

import 'package:benchmark_client/src/protocol/note.dart' as _ibqxzvsy;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

import 'protocol.dart' as _il2as5qe;

/// Benchmark API as Serverpod RPC methods (POST /note/<method>), which is how
/// Serverpod apps are normally called. The k6 scenarios map the shared
/// operations onto these methods (api_style: serverpod_rpc in backend.yaml).
/// {@category Endpoint}
class EndpointNote extends _isc.EndpointRef {
  EndpointNote(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'note';

  _ida.Future<_ibqxzvsy.Note> createNote(_ibqxzvsy.Note note) => caller
      .callServerEndpoint<_ibqxzvsy.Note>('note', 'createNote', {'note': note});

  _ida.Future<List<_ibqxzvsy.Note>> getNotes(int limit, int offset) =>
      caller.callServerEndpoint<List<_ibqxzvsy.Note>>('note', 'getNotes', {
        'limit': limit,
        'offset': offset,
      });

  _ida.Future<_ibqxzvsy.Note?> getNote(int id) =>
      caller.callServerEndpoint<_ibqxzvsy.Note?>('note', 'getNote', {'id': id});

  _ida.Future<Map<String, String>> noDbEndpoint() => caller
      .callServerEndpoint<Map<String, String>>('note', 'noDbEndpoint', {});
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_isc.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    note = EndpointNote(this);
  }

  late final EndpointNote note;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {'note': note};

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
