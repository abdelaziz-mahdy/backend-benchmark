foam.CLASS({
  package: 'bench.notes',
  name: 'NoDbWebAgent',

  documentation: 'GET /no_db_endpoint/: a fixed JSON message, no DAO access.',

  implements: [
    'foam.core.http.WebAgent'
  ],

  javaImports: [
    'jakarta.servlet.http.HttpServletResponse',
    'java.io.PrintWriter'
  ],

  methods: [
    {
      name: 'execute',
      args: 'Context x',
      javaCode: `
        HttpServletResponse resp = x.get(HttpServletResponse.class);
        resp.setStatus(HttpServletResponse.SC_OK);
        resp.setContentType("application/json");
        x.get(PrintWriter.class).print("{\\"message\\":\\"No db endpoint\\"}");
      `
    }
  ]
});
