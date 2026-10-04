package bench.notes;

import foam.core.http.NanoRouter;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * FOAM's NanoRouter serves CSpec services under /service/<name>/...
 * The benchmark contract wants them at the root (/notes/, /health, ...), so
 * this maps /<name>/... to /service/<name>/... and lets NanoRouter do the
 * rest: CSpec lookup, the authenticate flag, PM logging.
 */
public class RootRouter
  extends NanoRouter
{
  @Override
  protected void service(HttpServletRequest req, HttpServletResponse resp)
    throws ServletException, IOException
  {
    String path = req.getRequestURI();
    if ( path == null || path.length() < 2 ) {
      // "/" names no service (NanoRouter would fail indexing the path).
      resp.sendError(HttpServletResponse.SC_NOT_FOUND);
      return;
    }
    final String uri = "/service" + path;
    super.service(new HttpServletRequestWrapper(req) {
      @Override
      public String getRequestURI() {
        return uri;
      }
    }, resp);
  }
}
