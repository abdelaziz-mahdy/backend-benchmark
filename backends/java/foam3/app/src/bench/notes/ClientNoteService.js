foam.CLASS({
  package: 'bench.notes',
  name: 'ClientNoteService',

  documentation: `Client stub for NoteService: every call becomes an RPCMessage
    sent through the delegate box (an HTTPBox to service/noteService, see the
    noteService CSpec's "client").`,

  implements: [
    'bench.notes.NoteService'
  ],

  properties: [
    {
      class: 'Stub',
      of: 'bench.notes.NoteService',
      name: 'delegate'
    }
  ]
});
