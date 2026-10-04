foam.CLASS({
  package: 'bench.notes',
  name: 'NoteServiceImpl',

  documentation: 'Server side of NoteService: delegates to noteDAO.',

  implements: [
    'bench.notes.NoteService'
  ],

  javaImports: [
    'foam.dao.ArraySink',
    'foam.dao.DAO',
    'java.util.List'
  ],

  constants: [
    { name: 'DEFAULT_LIMIT', type: 'long',   value: 20 },
    { name: 'MAX_LIMIT',     type: 'long',   value: 1000 },
    { name: 'NO_DB_MESSAGE', type: 'String', value: 'No db endpoint' }
  ],

  methods: [
    {
      name: 'createNote',
      javaCode: `
        if ( note == null ) throw new IllegalArgumentException("note required");
        // The DAO owns ids: clear any client-supplied id so SequenceNumberDAO assigns one.
        Note n = (Note) note.fclone();
        n.clearProperty("id");
        return (Note) ((DAO) x.get("noteDAO")).put(n);
      `
    },
    {
      name: 'getNotes',
      javaCode: `
        long l = limit  <= 0 ? DEFAULT_LIMIT : Math.min(limit, MAX_LIMIT);
        long o = offset <  0 ? 0 : offset;
        List rows = ((ArraySink) ((DAO) x.get("noteDAO"))
          .orderBy(Note.ID)
          .skip(o)
          .limit(l)
          .select(new ArraySink())).getArray();
        return (Note[]) rows.toArray(new Note[rows.size()]);
      `
    },
    {
      name: 'getNote',
      javaCode: `
        return (Note) ((DAO) x.get("noteDAO")).find(id);
      `
    },
    {
      name: 'noDb',
      javaCode: `
        return NO_DB_MESSAGE;
      `
    }
  ]
});
