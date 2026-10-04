foam.CLASS({
  package: 'bench.notes',
  name: 'NoteHealthWebAgent',

  documentation: `GET /health: 200 once noteDAO is built and, in the postgres
    variant, Postgres answers a connection check.`,

  implements: [
    'foam.core.http.WebAgent'
  ],

  javaImports: [
    'foam.dao.jdbc.JDBCConnectionSpec',
    'jakarta.servlet.http.HttpServletResponse',
    'java.io.PrintWriter',
    'java.sql.Connection',
    'java.sql.DriverManager'
  ],

  methods: [
    {
      name: 'execute',
      args: 'Context x',
      javaCode: `
        HttpServletResponse resp = x.get(HttpServletResponse.class);
        boolean ok = x.get("noteDAO") != null;

        if ( ok && "postgres".equals(System.getenv("BENCH_VARIANT")) ) {
          JDBCConnectionSpec spec = (JDBCConnectionSpec) x.get("JDBCConnectionSpec");
          try ( Connection c = DriverManager.getConnection(spec.buildConnectionURI()) ) {
            ok = c.isValid(2);
          } catch ( Throwable t ) {
            ok = false;
          }
        }

        resp.setStatus(ok ? HttpServletResponse.SC_OK : HttpServletResponse.SC_SERVICE_UNAVAILABLE);
        resp.setContentType("application/json");
        x.get(PrintWriter.class).print(ok ? "{\\"status\\":\\"UP\\"}" : "{\\"status\\":\\"DOWN\\"}");
      `
    }
  ]
});
