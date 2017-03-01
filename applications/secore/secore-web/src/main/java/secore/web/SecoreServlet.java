/*
 * This file is part of rasdaman community.
 *
 * Rasdaman community is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Rasdaman community is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with rasdaman community.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2003 - 2012 Peter Baumann / rasdaman GmbH.
 *
 * For more information please see <http://www.rasdaman.org>
 * or contact Peter Baumann via <baumann@rasdaman.com>.
 */
package secore.web;

import java.io.FileNotFoundException;
import secore.req.ResolveResponse;
import secore.req.ResolveRequest;
import secore.Resolver;
import secore.db.DbManager;
import secore.util.StringUtil;
import secore.util.SecoreException;
import secore.util.ExceptionCode;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import net.opengis.ows.v_1_0_0.ExceptionReport;
import net.opengis.ows.v_1_0_0.ExceptionType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import secore.db.DbSecoreVersion;
import static secore.util.Constants.*;

/**
 * Web front-end for SECORE.
 *
 * @author Dimitar Misev
 */
public class SecoreServlet extends HttpServlet {

    private static Logger log = LoggerFactory.getLogger(SecoreServlet.class);

    private static final String CONTENT_TYPE = "text/xml; charset=utf-8";
    /**
     * cached the request and the result of the request
     */
    private static Map<String, String> cache = new HashMap<String, String>();

    @Override
    public void init() throws ServletException {
        try {
            //  Create (first time load) or Get the BaseX database from caches.
            DbManager dbManager = DbManager.getInstance();

            // NOTE: we need to check current version of Secoredb first, if it is not latest, then run the update definition files with the current version to the newest versionNumber from files.
            // in $RMANHOME/share/rasdaman/secore.
            // if current version of Secoredb is empty then add SecoreVersion element to BaseX database and run all the db_updates files.
            DbSecoreVersion dbSecoreVersion = new DbSecoreVersion(dbManager.getDb());
            dbSecoreVersion.handle();
            log.debug("Initialze BaseX dbs successfully.");
        } catch (SecoreException ex) {
            log.error("Cannot initialize database manager, exception caught: ", ex);
        } catch (FileNotFoundException ex) {
            log.error("Cannot update SECORE version from files, exception caught: ", ex);
        } catch (IOException ex) {
            log.error("Cannot update SECORE version from files, exception caught: ", ex);
        }
    }

    @Override
    protected  void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        doGet(req, resp);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        StringUtil.SERVLET_CONTEXT = req.getContextPath();
        String uri = req.getRequestURL().toString();
        uri = StringUtil.removeDuplicateDef(uri);
        String qs = req.getQueryString();
        if (qs != null && !qs.equals(EMPTY)) {
            uri += QUERY_SEPARATOR + qs;
        }
        try {
            ResolveRequest request = new ResolveRequest(uri);

            // Check if last query modified the baseX (insert/update/delete definitions) then it have to clear cache both in BaseX and on Servlet
            if (DbManager.getNeedToClearCache()) {
                cache = new HashMap<String, String>();
                DbManager.clearedCache();
                log.debug("Cleared cache on servlet.");
            }

            // NOTE: use the cache instead of querying collections if URI does exist in the cache
            String data = "";
            if (cache.containsKey(uri)) {
                log.debug("Query data from *cache* for URI request: {}", uri);
                data = cache.get(uri);
            } else {
                ResolveResponse res = Resolver.resolve(request);
                data = res.getData();
                log.debug("Query data from *collections* for URI request: {}", uri);
                addUriToCache(uri, data);
            }
            writeResult(req, resp, data);
        } catch (SecoreException ex) {
            writeError(resp, ex);
        }
    }

    private void writeResult(HttpServletRequest req, HttpServletResponse resp, String s) throws ServletException, IOException {
        PrintWriter out = resp.getWriter();
        resp.setContentType(CONTENT_TYPE);
        if (s.equals(XML_DECL + NEW_LINE)) {
            SecoreException ce = new SecoreException(ExceptionCode.NoSuchDefinition, "The requested resource was not found");
            writeError(resp, ce);
        } else {
            out.write(s);
        }
        out.flush();
        out.close();
    }

    private void writeError(HttpServletResponse resp, SecoreException ex) throws IOException {
        log.error("Exception caught:", ex);
        String output = exceptionToXml(ex);
        resp.setContentType(CONTENT_TYPE);
        resp.setStatus(ex.getExceptionCode().getHttpErrorCode());
        PrintWriter out = resp.getWriter();
        out.println(output);
        out.close();
    }

    private String exceptionToXml(SecoreException ex) {
        ExceptionReport report = ex.getReport();
        StringBuilder ret = new StringBuilder(500);
        ret.append(XML_DECL);
        ret.append(NEW_LINE);
        ret.append("<ows:ExceptionReport version=\"2.0.0\""
                   + " xsd:schemaLocation=\"http://www.opengis.net/ows/2.0 http://schemas.opengis.net/ows/2.0/owsExceptionReport.xsd\""
                   + " xmlns:ows=\"http://www.opengis.net/ows/2.0\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n");
        for (ExceptionType exception : report.getException()) {
            ret.append("  <ows:Exception exceptionCode=\"").append(exception.getExceptionCode()).append("\"");
            if (exception.getLocator() != null) {
                ret.append(" locator=\"").append(exception.getLocator()).append("\"");
            }
            ret.append(">\n");
            ret.append("    <ows:ExceptionText>").append(StringUtil.ltos(exception.getExceptionText(), '\n')).append("</ows:ExceptionText>\n");
            ret.append("  </ows:Exception>\n");
        }
        ret.append("</ows:ExceptionReport>");
        return ret.toString();
    }

    /**
     * If URI does not exist in the cache then add the URI and data to the cache
     * @param uri
     * @param data
     */
    private void addUriToCache(String uri, String data) {
        if (!cache.containsKey(uri)) {
            cache.put(uri, data);
        }
    }
}
