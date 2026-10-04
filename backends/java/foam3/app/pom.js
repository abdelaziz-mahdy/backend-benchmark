// Root POM for the FOAM3 benchmark app (layout from foam3's setup/Project tool).
foam.POM({
  name: 'bench',
  excludes: [ '*' ],
  projects: [
    { name: 'foam3/pom' },
    { name: 'src/bench/notes/pom' },
    { name: 'journals/pom' }
  ],
  envs: {
    version: '1.0.0'
  },
  tasks: [
    function javaManifest() {
      JAVA_MANIFEST_VENDOR_ID = 'bench.notes';
    }
  ]
});
