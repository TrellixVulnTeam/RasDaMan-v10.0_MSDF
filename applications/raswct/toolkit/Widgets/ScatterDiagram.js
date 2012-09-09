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
* Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009 Peter Baumann / rasdaman GmbH.
*
* For more information please see <http://www.rasdaman.org>
* or contact Peter Baumann via <baumann@rasdaman.com>.
/

/* 
 * Defines an a widget used for displaying scattered diagrams.
 * 
 * @author Alex Dumitru <m.dumitru@jacobs-university.de>
 * @author Vlad Merticariu <v.merticariu@jacobs-university.de>
 * @package raswct
 * @version 1.0.0
 */

Rj.namespace('Rj.Widget');

Rj.Widget.ScatterDiagram = new JS.Class(Rj.Widget.BaseChart, {
  
  /**
   * @param <string> title - the title of this diagram
   * @param <string> xAxisTitle - the title of the x Axis
   * @param <string> yAxisTitle - the title of the y Axis
   */
  initialize: function(title, xAxisTitle, yAxisTitle){
    this.callSuper(title, xAxisTitle, yAxisTitle);    
    this.processed = false;
  },
  
  configure : function(cfg){
    this.callSuper();
    this.cfg.seriesDefaults = this.cfg.seriesDefaults || {};
    this.cfg.seriesDefaults.renderer = jQuery.jqplot.LineRenderer;    
    this.cfg.seriesDefaults.showLine = false;        
    if(!cfg){
      cfg = {};
    }
    this.cfg = jQuery.extend(this.cfg, cfg);
    return this.cfg
  }    
    
});
