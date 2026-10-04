foam.INTERFACE({
  package: 'bench.notes',
  name: 'NoteService',

  documentation: `The benchmark's four operations as a FOAM service.
    skeleton: true generates bench.notes.NoteServiceSkeleton, which the
    noteService CSpec uses as its boxClass, so the service is called with
    FOAM's box RPC (POST /service/noteService, an Envelope holding an
    RPCMessage).`,

  skeleton: true,

  methods: [
    {
      name: 'createNote',
      documentation: 'Store a note; the DAO assigns the id. Returns the stored note.',
      async: true,
      type: 'bench.notes.Note',
      args: 'Context x, bench.notes.Note note'
    },
    {
      name: 'getNotes',
      documentation: 'Notes ordered by id, skipping offset, at most limit.',
      async: true,
      type: 'bench.notes.Note[]',
      args: 'Context x, Long limit, Long offset'
    },
    {
      name: 'getNote',
      documentation: 'The note with this id, or null.',
      async: true,
      type: 'bench.notes.Note',
      args: 'Context x, Long id'
    },
    {
      name: 'noDb',
      documentation: 'A constant message; touches no DAO.',
      async: true,
      type: 'String',
      args: 'Context x'
    }
  ]
});
