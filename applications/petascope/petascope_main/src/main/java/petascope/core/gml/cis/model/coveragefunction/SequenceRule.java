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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU  General Public License for more details.
 *
 * You should have received a copy of the GNU  General Public License
 * along with rasdaman community.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2003 - 2018 Peter Baumann / rasdaman GmbH.
 *
 * For more information please see <http://www.rasdaman.org>
 * or contact Peter Baumann via <baumann@rasdaman.com>.
 */
package petascope.core.gml.cis.model.coveragefunction;

import nu.xom.Attribute;
import nu.xom.Element;
import petascope.core.XMLSymbols;
import static petascope.core.XMLSymbols.ATT_AXIS_ORDER;
import static petascope.core.XMLSymbols.LABEL_SEQUENCE_RULE;
import static petascope.core.XMLSymbols.NAMESPACE_GML;
import static petascope.core.XMLSymbols.PREFIX_GML;
import static petascope.core.XMLSymbols.VALUE_SEQUENCE_RULE_TYPE_DEFAULT;
import petascope.core.gml.ISerializeToXMElement;
import petascope.util.XMLUtil;

/**
 * Class to represent sequenceRule element in CIS 1.0. e.g:
 * 
 <gml:sequenceRule axisOrder="+1 +2">Linear</gml:sequenceRule>
 * 
 * @author Bang Pham Huu <b.phamhuu@jacobs-university.de>
 */
public class SequenceRule implements ISerializeToXMElement {
    
    private String axisOrder;
    private String type = XMLSymbols.VALUE_SEQUENCE_RULE_TYPE_DEFAULT;

    public SequenceRule(String axisOrder) {
        this.axisOrder = axisOrder;
    }
    
    public String getAxisOrder() {
        return axisOrder;
    }

    public void setAxisOrder(String axisOrder) {
        this.axisOrder = axisOrder;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    @Override
    public Element serializeToXMLElement() {
        Element sequenceRuleElement = new Element(XMLUtil.createXMLLabel(PREFIX_GML, LABEL_SEQUENCE_RULE), NAMESPACE_GML);
        Attribute axisOrderAttribute = new Attribute(ATT_AXIS_ORDER, axisOrder);
        
        sequenceRuleElement.addAttribute(axisOrderAttribute);
        sequenceRuleElement.appendChild(VALUE_SEQUENCE_RULE_TYPE_DEFAULT);
        
        return sequenceRuleElement;
    }
}
