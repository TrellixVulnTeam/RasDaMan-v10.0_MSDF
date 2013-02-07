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
package petascope.wcps.server.core;

import petascope.core.Metadata;
import petascope.exceptions.PetascopeException;
import petascope.exceptions.WCPSException;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Vector;
import org.w3c.dom.*;
import petascope.util.CrsUtil;
import petascope.util.WCPSConstants;

public class ConstructCoverageExpr implements IRasNode, ICoverageInfo {

    private String covName;
    private Vector<AxisIterator> iterators;
    private IRasNode values;
    private CoverageInfo info;
    private String axisIteratorString;
    private String newIteratorName;

    public ConstructCoverageExpr(Node node, XmlQuery xq)
            throws WCPSException {
        while ((node != null) && node.getNodeName().equals("#" + WCPSConstants.MSG_TEXT)) {
            node = node.getNextSibling();
        }

        iterators = new Vector();
        newIteratorName = xq.registerNewExpressionWithVariables();

        while (node != null) {
            String name = node.getNodeName();
            if (name.equals(WCPSConstants.MSG_NAME)) {
                covName = node.getTextContent();
            } else if (name.equals(WCPSConstants.MSG_AXIS_ITERATOR)) {
                AxisIterator it = new AxisIterator(node.getFirstChild(), xq, newIteratorName);
                iterators.add(it);
                // Top level structures need to know about these iterators
                CoverageIterator dyn = new CoverageIterator(it.getVar(), covName);
                xq.addDynamicCoverageIterator(dyn);
            } else {
                /* The iterator is probably used in the "values" section,
                 * so send the iterator to the top-level query */
                if (covName != null && iterators.size() > 0) {
                    try {
                        buildMetadata(xq);
                    } catch (PetascopeException ex) {
                        throw new WCPSException(WCPSConstants.ERRTXT_CANNOT_BUILD_COVERAGE);
                    }
                } else {
                    throw new WCPSException(WCPSConstants.ERRTXT_CANNOT_BUILD_COVERAGE);
                }
                // And only then start parsing the "values" section 
                values = new CoverageExpr(node, xq);
            }

            node = node.getNextSibling();
            while ((node != null) && node.getNodeName().equals("#" + WCPSConstants.MSG_TEXT)) {
                node = node.getNextSibling();
            }
        }

        buildAxisIteratorDomain();

        // Sanity check: metadata should have already been build
        if (info == null) {
            throw new WCPSException(WCPSConstants.ERRTXT_CANNOT_BUILD_COVERAGE);
        }
    }

    public String toRasQL() {
        String result = WCPSConstants.MSG_MARRAY + " ";
        result += axisIteratorString;
        result += " " + WCPSConstants.MSG_VALUES + " " + values.toRasQL();

        return result;
    }

    public CoverageInfo getCoverageInfo() {
        return info;
    }

    /* Concatenates all the AxisIterators into one large multi-dimensional object,
     * that will be used to build to RasQL query */
    private void buildAxisIteratorDomain() {
        axisIteratorString = "";
        axisIteratorString += newIteratorName + " " + WCPSConstants.MSG_IN + " [";

        for (int i = 0; i < iterators.size(); i++) {
            if (i > 0) {
                axisIteratorString += ", ";
            }
            AxisIterator ai = iterators.elementAt(i);
            axisIteratorString += ai.getInterval();
        }

        axisIteratorString += "]";
    }

    /** Builds full metadata for the newly constructed coverage **/
    private void buildMetadata(XmlQuery xq) throws WCPSException, PetascopeException {
        List<CellDomainElement> cellDomainList = new LinkedList<CellDomainElement>();
        List<RangeElement> rangeList = new LinkedList<RangeElement>();
        HashSet<String> nullSet = new HashSet<String>();
        String nullDefault = "0";
        nullSet.add(nullDefault);
        HashSet<InterpolationMethod> interpolationSet = new HashSet<InterpolationMethod>();
        InterpolationMethod interpolationDefault = new InterpolationMethod(WCPSConstants.MSG_NONE, 
                WCPSConstants.MSG_NONE);
        interpolationSet.add(interpolationDefault);
        String coverageName = covName;
        List<DomainElement> domainList = new LinkedList<DomainElement>();

        Iterator<AxisIterator> i = iterators.iterator();
        while (i.hasNext()) {
            // Build domain metadata
            AxisIterator ai = i.next();
            String axisName = ai.getVar();
            String axisType = ai.getAxisType();
            cellDomainList.add(new CellDomainElement(ai.getLow(), ai.getHigh(), axisType));
            String crs = CrsUtil.GRID_CRS;
            HashSet<String> crsset = new HashSet<String>();
            crsset.add(crs);
            DomainElement domain = new DomainElement(axisName, axisType,
                    ai.getLow().doubleValue(), ai.getHigh().doubleValue(),
                    null, null, crsset, xq.getMetadataSource().getAxisNames(), null); // FIXME uom = null
            domainList.add(domain);
        }

        // "unsigned int" is default datatype
        rangeList.add(new RangeElement(WCPSConstants.MSG_DYNAMIC_TYPE, WCPSConstants.MSG_UNSIGNED_INT, null));
        Metadata metadata = new Metadata(cellDomainList, rangeList, nullSet,
                nullDefault, interpolationSet, interpolationDefault,
                coverageName, WCPSConstants.MSG_GRID_COVERAGE, domainList, null); // FIXME
        // Let the top-level query know the full metadata about us
        xq.getMetadataSource().addDynamicMetadata(covName, metadata);
        info = new CoverageInfo(metadata);
    }
}
