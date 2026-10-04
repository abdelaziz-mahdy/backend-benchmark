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

import 'package:serverpod_client/serverpod_client.dart' as _i1;

import 'dart:async' as _i2;

import 'package:benchmark_client/src/protocol/note.dart' as _i3;

import 'protocol.dart' as _i4;

/// Benchmark API as Serverpod RPC methods (POST /note/<method>), which is how
/// Serverpod apps are normally called. The k6 scenarios map the shared
/// operations onto these methods (api_style: serverpod_rpc in backend.yaml).
/// {@category Endpoint}
class EndpointNote extends _i1.EndpointRef {
  EndpointNote(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'note';

  _i2.Future<_i3.Note> createNote(_i3.Note note) =>
      caller.callServerEndpoint<_i3.Note>('note', 'createNote', {'note': note});

  _i2.Future<List<_i3.Note>> getNotes(int limit, int offset) =>
      caller.callServerEndpoint<List<_i3.Note>>('note', 'getNotes', {
        'limit': limit,
        'offset': offset,
      });

  _i2.Future<_i3.Note?> getNote(int id) =>
      caller.callServerEndpoint<_i3.Note?>('note', 'getNote', {'id': id});

  _i2.Future<Map<String, String>> noDbEndpoint() => caller
      .callServerEndpoint<Map<String, String>>('note', 'noDbEndpoint', {});
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_i1.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i4.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    note = EndpointNote(this);
  }

  late final EndpointNote note;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {'note': note};

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
