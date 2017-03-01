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
package secore;

import secore.req.ResolveResponseTest;
import secore.handler.ParameterizedCrsHandlerTest;
import secore.handler.GeneralHandlerTest;
import secore.db.DbManagerTest;
import secore.util.ConfigTest;
import secore.util.StringUtilTest;
import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import secore.handler.CrsCompoundHandlerTest;
import secore.handler.EqualityHandlerTest;
import secore.handler.IncompleteUrlHandlerTest;
import secore.req.RequestParamTest;
import secore.req.ResolveRequestTest;

/**
 * Test suite runner.
 *
 * @author Dimitar Misev
 */
@RunWith(Suite.class)
@Suite.SuiteClasses({
    RequestParamTest.class,
    ResolveRequestTest.class,
    ResolveResponseTest.class,
    StringUtilTest.class,
    ConfigTest.class,
    DbManagerTest.class,

    GeneralHandlerTest.class,
    ParameterizedCrsHandlerTest.class,
    CrsCompoundHandlerTest.class,
    EqualityHandlerTest.class,
    IncompleteUrlHandlerTest.class
})
public class AllTests {
}
