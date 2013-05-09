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

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.*;
import petascope.exceptions.WCPSException;
import petascope.util.WCPSConstants;

public class BinaryOperationCoverageExpr extends AbstractRasNode implements ICoverageInfo {
    
    private static Logger log = LoggerFactory.getLogger(BinaryOperationCoverageExpr.class);
    
    public static final Set<String> NODE_NAMES = new HashSet<String>();
    private static final String[] NODE_NAMES_ARRAY = {
        WCPSConstants.MSG_PLUS_S,
        WCPSConstants.MSG_MINUS_S,
        WCPSConstants.MSG_MULT,
        WCPSConstants.MSG_DIV_S,
        WCPSConstants.MSG_AND,
        WCPSConstants.MSG_OR,
        WCPSConstants.MSG_EQUALS,
        WCPSConstants.MSG_LESS_THAN,
        WCPSConstants.MSG_GREATER_THAN,
        WCPSConstants.MSG_LESS_OR_EQUAL,
        WCPSConstants.MSG_GREATER_OR_EQUAL,
        WCPSConstants.MSG_OVERLAY,
        WCPSConstants.MSG_NOT_EQUALS,
    };
    static {
        NODE_NAMES.addAll(Arrays.asList(NODE_NAMES_ARRAY));
    }

    private IRasNode first, second;
    private CoverageExprPairType pair;
    private CoverageInfo info;
    private String operation;

    public BinaryOperationCoverageExpr(Node node, XmlQuery xq)
            throws WCPSException {
        String nodeName = node.getNodeName();
        log.trace(nodeName);

        boolean okay = false;    // will be true if the node is recognized

        if (nodeName.equals(WCPSConstants.MSG_PLUS_S)) {
            operation = WCPSConstants.MSG_PLUS;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_MINUS_S)) {
            operation = WCPSConstants.MSG_MINUS;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_MULT)) {
            operation = WCPSConstants.MSG_STAR;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_DIV_S)) {
            operation = WCPSConstants.MSG_DIV;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_AND) || nodeName.equals(WCPSConstants.MSG_OR) || nodeName.equals("xor")) {
            operation = nodeName;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_EQUALS)) {
            operation = WCPSConstants.MSG_EQUAL;
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_LESS_THAN)) {
            operation = "<";
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_GREATER_THAN)) {
            operation = ">";
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_LESS_OR_EQUAL)) {
            operation = "<=";
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_GREATER_OR_EQUAL)) {
            operation = ">=";
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_NOT_EQUALS)) {
            operation = "!=";
            okay = true;
        } else if (nodeName.equals(WCPSConstants.MSG_OVERLAY)) {
            operation = WCPSConstants.MSG_OVERLAY;
            okay = true;
        }

        if (!okay) {
            throw new WCPSException(WCPSConstants.ERRTXT_UNEXPECTED_BINARY + " : " + nodeName);
        }
        log.trace("  " + WCPSConstants.MSG_OPERATION + ": " + operation);
        
        Node operand = node.getFirstChild();
        while (operand.getNodeName().equals("#" + WCPSConstants.MSG_TEXT)) {
            operand = operand.getNextSibling();
        }

        pair = new CoverageExprPairType(operand, xq);
        info = new CoverageInfo(((ICoverageInfo) pair).getCoverageInfo());
        first = pair.getFirst();
        second = pair.getSecond();
        
        // Keep the children to let XML tree be re-traversed
        super.children.addAll(Arrays.asList(first, second));
    }

    public CoverageInfo getCoverageInfo() {
        return info;
    }

    public String toRasQL() {
        String ret = "";
        if (operation.equals(WCPSConstants.MSG_OVERLAY)) {
            // overlay is reversed in rasql
            ret = "((" + second.toRasQL() + ")" + operation + "(" + first.toRasQL() + "))";
        } else {
            ret = "((" + first.toRasQL() + ")" + operation + "(" + second.toRasQL() + "))";
        }
        return ret;
    }
}
