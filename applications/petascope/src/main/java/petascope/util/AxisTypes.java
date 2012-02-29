/*
 * This file is part of rasdaman community.
 *
 * Rasdaman community is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Rasdaman community is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with rasdaman community.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2003 - 2010 Peter Baumann / rasdaman GmbH.
 *
 * For more information please see <http://www.rasdaman.org>
 * or contact Peter Baumann via <baumann@rasdaman.com>.
 */
package petascope.util;

/**
 *
 * @author <a href="mailto:cmppri@unife.it">Piero Campalani</a>
 */
public interface AxisTypes {
    // As stored in *petascopedb* (ps_axistype table):
    public static final String X_AXIS       = "x";
    public static final String Y_AXIS       = "y";
    public static final String ELEV_AXIS    = "elevation";
    public static final String TEMPORAL_AXIS = "temporal";
    public static final String T_AXIS       = "t";
    public static final String OTHER        = "other";
}
