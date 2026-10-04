foam.CLASS({
  package: 'bench.notes',
  name: 'NoteWebAgent',

  documentation: `REST front for noteDAO.
    POST /notes/                      put a Note, id assigned by the DAO's SequenceNumberDAO
    GET  /notes/?limit=20&offset=N    noteDAO.orderBy(ID).skip(N).limit(20)
    GET  /notes/{id}                  noteDAO.find(id), 404 when missing`,

  implements: [
    'foam.core.http.WebAgent'
  ],

  javaImports: [
    'foam.dao.ArraySink',
    'foam.dao.DAO',
    'foam.lang.FObject',
    'foam.lib.formatter.JSONFObjectFormatter',
    'foam.lib.json.JSONParser',
    'jakarta.servlet.http.HttpServletRequest',
    'jakarta.servlet.http.HttpServletResponse',
    'java.io.BufferedReader',
    'java.io.PrintWriter',
    'java.util.List'
  ],

  constants: [
    { name: 'DEFAULT_LIMIT', type: 'long', value: 20 },
    { name: 'MAX_LIMIT',     type: 'long', value: 1000 }
  ],

  methods: [
    {
      name: 'execute',
      args: 'Context x',
      javaCode: `
        HttpServletRequest  req  = x.get(HttpServletRequest.class);
        HttpServletResponse resp = x.get(HttpServletResponse.class);
        DAO                 dao  = (DAO) x.get("noteDAO");

        // The router hands us /service/notes[/<id>][/]; take what follows "notes".
        String uri  = req.getRequestURI();
        int    at   = uri.indexOf("/notes");
        String rest = at < 0 ? "" : uri.substring(at + "/notes".length());
        while ( rest.startsWith("/") ) rest = rest.substring(1);
        while ( rest.endsWith("/") )   rest = rest.substring(0, rest.length() - 1);

        String method = req.getMethod();
        try {
          if ( rest.isEmpty() && "POST".equals(method) ) {
            create(x, dao, req, resp);
          } else if ( rest.isEmpty() && "GET".equals(method) ) {
            list(x, dao, req, resp);
          } else if ( ! rest.isEmpty() && "GET".equals(method) ) {
            long id;
            try {
              id = Long.parseLong(rest);
            } catch ( NumberFormatException e ) {
              error(x, resp, HttpServletResponse.SC_NOT_FOUND, "Not found");
              return;
            }
            FObject note = dao.find(id);
            if ( note == null ) {
              error(x, resp, HttpServletResponse.SC_NOT_FOUND, "Not found");
            } else {
              write(x, resp, HttpServletResponse.SC_OK, note);
            }
          } else {
            error(x, resp, HttpServletResponse.SC_METHOD_NOT_ALLOWED, "Method not allowed");
          }
        } catch ( java.io.IOException e ) {
          error(x, resp, HttpServletResponse.SC_BAD_REQUEST, "Bad request");
        }
      `
    },
    {
      name: 'create',
      args: 'Context x, foam.dao.DAO dao, HttpServletRequest req, HttpServletResponse resp',
      javaThrows: [ 'java.io.IOException' ],
      javaCode: `
        StringBuilder  body   = new StringBuilder();
        BufferedReader reader = req.getReader();
        char[]         buf    = new char[1024];
        int            n;
        while ( ( n = reader.read(buf) ) != -1 ) body.append(buf, 0, n);

        JSONParser parser = new JSONParser();
        parser.setX(x);
        Note note = (Note) parser.parseString(body.toString(), Note.class);
        if ( note == null ) {
          error(x, resp, HttpServletResponse.SC_BAD_REQUEST, "Invalid JSON");
          return;
        }
        // The DAO owns ids: clear any client-supplied id so SequenceNumberDAO assigns one.
        note.clearProperty("id");

        FObject created = dao.put(note);
        if ( created == null ) {
          error(x, resp, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Insert failed");
          return;
        }
        write(x, resp, HttpServletResponse.SC_CREATED, created);
      `
    },
    {
      name: 'list',
      args: 'Context x, foam.dao.DAO dao, HttpServletRequest req, HttpServletResponse resp',
      javaCode: `
        long limit  = param(req, "limit",  DEFAULT_LIMIT);
        long offset = param(req, "offset", 0);
        if ( limit <= 0 ) limit = DEFAULT_LIMIT;
        if ( limit > MAX_LIMIT ) limit = MAX_LIMIT;
        if ( offset < 0 ) offset = 0;

        ArraySink sink = (ArraySink) dao
          .orderBy(Note.ID)
          .skip(offset)
          .limit(limit)
          .select(new ArraySink());

        List                 rows = sink.getArray();
        JSONFObjectFormatter fmt  = formatter(x);
        fmt.append('[');
        for ( int i = 0 ; i < rows.size() ; i++ ) {
          if ( i > 0 ) fmt.append(',');
          fmt.output((FObject) rows.get(i), Note.getOwnClassInfo());
        }
        fmt.append(']');
        send(x, resp, HttpServletResponse.SC_OK, fmt.builder());
      `
    },
    {
      name: 'param',
      args: 'HttpServletRequest req, String name, long dflt',
      type: 'long',
      javaCode: `
        String v = req.getParameter(name);
        if ( v == null || v.isEmpty() ) return dflt;
        try {
          return Long.parseLong(v);
        } catch ( NumberFormatException e ) {
          return dflt;
        }
      `
    },
    {
      name: 'formatter',
      args: 'Context x',
      type: 'foam.lib.formatter.JSONFObjectFormatter',
      javaCode: `
        JSONFObjectFormatter fmt = new JSONFObjectFormatter(x);
        fmt.setQuoteKeys(true);
        fmt.setOutputClassNames(false);
        fmt.setOutputDefaultValues(true);
        return fmt;
      `
    },
    {
      name: 'write',
      args: 'Context x, HttpServletResponse resp, int status, foam.lang.FObject obj',
      javaCode: `
        JSONFObjectFormatter fmt = formatter(x);
        fmt.output(obj, Note.getOwnClassInfo());
        send(x, resp, status, fmt.builder());
      `
    },
    {
      name: 'error',
      args: 'Context x, HttpServletResponse resp, int status, String message',
      javaCode: `
        send(x, resp, status, "{\\"error\\":\\"" + message + "\\"}");
      `
    },
    {
      name: 'send',
      args: 'Context x, HttpServletResponse resp, int status, CharSequence body',
      javaCode: `
        resp.setStatus(status);
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");
        PrintWriter out = x.get(PrintWriter.class);
        out.append(body);
      `
    }
  ]
});
