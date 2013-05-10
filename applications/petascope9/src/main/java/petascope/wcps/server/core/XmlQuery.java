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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.*;
import petascope.core.IDynamicMetadataSource;
import petascope.exceptions.PetascopeException;
import petascope.exceptions.WCPSException;
import petascope.util.WCPSConstants;

/**
 *
 * @author Andrei Aiordachioaie
 */
public class XmlQuery extends AbstractRasNode {
    
    private static Logger log = LoggerFactory.getLogger(XmlQuery.class);

    private String mime;
    private ArrayList<CoverageIterator> iterators;
    private BooleanScalarExpr where;
    private IRasNode coverageExpr;
    private IDynamicMetadataSource meta;
    private ArrayList<CoverageIterator> dynamicIterators;
    /* Variables used in the XML query are renamed. The renaming is explained below.
     *
     * Variables declared in the same expression (construct, const, condense)
    will be collapsed into one multidimensional variable name. For
    "construct img over $px x(1:10), $py y(1:10) values ... ", the variables could
    be translated as: $px -> "iteratorA[0]", $py -> "iteratorA[1]".
     * Variables declared in different expression will have different prefixes,
    built from "varPrefix" + "varStart".
     *

     * Used in condenser, construct and constant coverage expressions. */
    // VariableIndexCount stores the dimensionality of each renamed variable
    private HashMap<String, Integer> varDimension;
    // VariableNewName is used to translate the old var name into the multi-dim var name
    private HashMap<String, String> variableTranslator;
    private String varPrefix = WCPSConstants.MSG_I + "_";
    private char varSuffix = 'i';

    public String getMimeType() {
        return mime;
    }

    public XmlQuery(IDynamicMetadataSource source) {
        super();
        this.meta = source;
        iterators = new ArrayList<CoverageIterator>();
        dynamicIterators = new ArrayList<CoverageIterator>();
        variableTranslator = new HashMap<String, String>();
        varDimension = new HashMap<String, Integer>();
    }

    public XmlQuery(Node node) throws WCPSException, PetascopeException {
        iterators = new ArrayList<CoverageIterator>();
        dynamicIterators = new ArrayList<CoverageIterator>();
        variableTranslator = new HashMap<String, String>();
        varDimension = new HashMap<String, Integer>();
        this.startParsing(node);
    }

    public void startParsing(Node node) throws WCPSException, PetascopeException {
        log.debug(WCPSConstants.DEBUGTXT_PROCESSING_XML_REQUEST + ": " + node.getNodeName());

        Node x = node.getFirstChild();


        while (x != null) {
            if (x.getNodeName().equals("#" + WCPSConstants.MSG_TEXT)) {
                x = x.getNextSibling();
                continue;
            }

            log.info(WCPSConstants.MSG_THE_CURRENT_NODE + ": " + x.getNodeName());

            if (x.getNodeName().equals(WCPSConstants.MSG_COVERAGE_ITERATOR)) {
                iterators.add(new CoverageIterator(x, this));
            } else if (x.getNodeName().equals(WCPSConstants.MSG_WHERE)) {
                where = new BooleanScalarExpr(x.getFirstChild(), this);
            } else if (x.getNodeName().equals(WCPSConstants.MSG_ENCODE)) {
                EncodeDataExpr encode;

                try {
                    encode = new EncodeDataExpr(x, this);
                } catch (WCPSException ex) {
                    throw ex;
                }
                coverageExpr = encode;
                mime = encode.getMime();
            } else {
                // It has to be a scalar Expr 
                coverageExpr = new ScalarExpr(x, this);
                mime = WCPSConstants.MSG_TEXT_PLAIN;
            }

            x = x.getNextSibling();
        }
    }

    public Boolean isIteratorDefined(String iteratorName) {
        Iterator<CoverageIterator> it = iterators.iterator();
        while (it.hasNext()) {
            CoverageIterator tmp = it.next();
            if (iteratorName.equals(tmp.getIteratorName())) {
                return true;
            }
        }

        it = dynamicIterators.iterator();
        while (it.hasNext()) {
            CoverageIterator tmp = it.next();
            if (iteratorName.equals(tmp.getIteratorName())) {
                return true;
            }
        }

        return false;
    }

    /* Stores information about dynamically created iterators, as metadata.
     * For example, from a Construct Coverage expression.
     */
    public void addDynamicCoverageIterator(CoverageIterator i) {
        dynamicIterators.add(i);
    }

    public Iterator<String> getCoverages(String iteratorName) throws WCPSException {
        for (int i = 0; i < iterators.size(); ++i) {
            if (iterators.get(i).getIteratorName().equals(iteratorName)) {
                return iterators.get(i).getCoverages();
            }
        }

        for (int i = 0; i < dynamicIterators.size(); ++i) {
            if (dynamicIterators.get(i).getIteratorName().equals(iteratorName)) {
                return dynamicIterators.get(i).getCoverages();
            }
        }

        throw new WCPSException(WCPSConstants.MSG_ITERATOR + " " + iteratorName + " " + WCPSConstants.ERRTXT_NOT_DEFINED);
    }

    public boolean isDynamicCoverage(String coverageName) {
        for (int i = 0; i < dynamicIterators.size(); ++i) {
            Iterator<String> iterator =
                    ((CoverageIterator) dynamicIterators.get(i)).getCoverages();
            while (iterator.hasNext()) {
                if (iterator.next().equals(coverageName)) {
                    return true;
                }
            }
        }

        return false;
    }

    /** Creates a new (translated) variable name for an expression that
     * has referenceable variables.
     * @return String a new variable name assigned
     */
    public String registerNewExpressionWithVariables() {
        String name = varPrefix + varSuffix;
        varDimension.put(name, 0);
        varSuffix++;
        return name;
    }

    /** Remember a variable that can be referenced in the future. This function
     * assigns it a index code, that should then be used to reference that variable
     * in the RasQL query.
     *
     * If the variable is already referenced, then this function does nothing.
     * @param name Variable name
     */
    public boolean addReferenceVariable(String name, String translatedName) {
        if (varDimension.containsKey(translatedName) == false) {
            return false;
        }

        Integer index = varDimension.get(translatedName);
        Integer newIndex = index + 1;
        varDimension.put(translatedName, newIndex);
        variableTranslator.put(name, translatedName + "[" + index + "]");

        return true;
    }

    /** Retrieve the translated name assigned to a specific reference (scalar) variable */
    public String getReferenceVariableName(String name) throws WCPSException {
        String newName = variableTranslator.get(name);
        return newName;
    }

    public String toRasQL() {
        String result = "";
        if (coverageExpr instanceof ScalarExpr &&
            ((ScalarExpr)coverageExpr).isMetadataExpr()) {
            // in this case we shouldn't make any rasql query
            result = coverageExpr.toRasQL();
        } else {
            // rasql query
            result = WCPSConstants.MSG_SELECT + " " + coverageExpr.toRasQL() + " " + WCPSConstants.MSG_FROM + " ";
            Iterator<CoverageIterator> it = iterators.iterator();
            boolean first = true;

            while (it.hasNext()) {
                if (first) {
                    first = false;
                } else {
                    result += ", ";
                }

                result += it.next().toRasQL();
            }

            if (where != null) {
                result += " " + WCPSConstants.MSG_WHERE+ " " + where.toRasQL();
            }
        }        
        return result;
    }

    public IDynamicMetadataSource getMetadataSource() {
        return meta;
    }
}
