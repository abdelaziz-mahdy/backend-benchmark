foam.POM({
  name: 'notes',
  files: [
    { name: 'Note',               flags: 'js|java' },
    { name: 'NoteService',        flags: 'js|java' },
    { name: 'ClientNoteService',  flags: 'js' },
    { name: 'NoteServiceImpl',    flags: 'java' },
    { name: 'NoteHealthWebAgent', flags: 'java' }
  ]
});
