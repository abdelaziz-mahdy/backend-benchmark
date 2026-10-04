foam.POM({
  name: 'notes',
  files: [
    { name: 'Note',             flags: 'js|java' },
    { name: 'NoteWebAgent',     flags: 'java' },
    { name: 'NoDbWebAgent',     flags: 'java' },
    { name: 'NoteHealthWebAgent', flags: 'java' }
  ],
  javaFiles: [
    { name: 'RootRouter' }
  ]
});
