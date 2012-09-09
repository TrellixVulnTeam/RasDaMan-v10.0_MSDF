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
 * Defines a widget used as a base for all charts.
 * 
 * @author Alex Dumitru <m.dumitru@jacobs-university.de>
 * @author Vlad Merticariu <v.merticariu@jacobs-university.de>
 * @package raswct
 * @version 1.0.0
 */

Rj.namespace("Rj.Widget");

Rj.Widget.BaseChart = new JS.Class(Rj.Widget.OutputWidget, {

  /**
   * @param <BaseQuery> query - the Query that is used to retrieve the data
   * @param <array> data - if static data needs to be used, it can be initialized here
   * @param <string> selector - any valid CSS3 or xPath selector that will identify the div in which the graph is placed
   * @param <string> title - the title of this diagram
   * @param <string> xAxisTitle - the title of the x Axis
   * @param <string> yAxisTitle - the title of the y Axis
   * @param <array> seriesColors - an array of colors of the series. The colors are assigned in the order given
   */
  initialize:function (title, xAxisTitle, yAxisTitle, seriesColors, extraOptions) {
    this.callSuper();
    this.data = [];
    this.widget = null;
    this.seriesNames = [];
    this.cfg = {
      title:title,

      axes          :{
        xaxis:{
          label:xAxisTitle || ""
        },
        yaxis:{
          label:yAxisTitle || ""
        }
      },
      cursor        :{
        show:true,
        zoom:true
      },
      highlighter   :{
        show:true
      },
      seriesDefaults:{
        rendererOptions:{
          smooth   :true,
          varyByColor : true,
          animation:{
            show:true
          }
        },
        showMarker     :true
      },
      legend        :{
        show    :true,
        location:'ne',
        xoffset :12,
        yoffset :12
      },
      seriesColors: seriesColors || [ "#AA0000", "#00AA00", "#0000AA", "#A0A0A0", "#CCBBAA"]

    };
    if (extraOptions) {
      this.cfg = jQuery.extend(this.cfg, extraOptions);
    }

  },

  /**
   * Adds a data series to the diagram
   * @param serie - an array of form [[0,1], [1,2]]
   * @param name - the name of the series
   * @return the index of the series - you will need it for the removeSeries
   */
  addDataSeries:function (serie, name) {
    this.data.push(serie);
    this.seriesNames.push({
      label : name || ""
      });
    if (this.widget != null) {
      //the plot is already rendered, redraw it
      this.renderTo(this.selector);
    }
    return (this.data.length - 1)
  },

  /**
   * Removes a data series from the chart
   * @param serieIndex - the index of the series @see addDataSeries
   * @param doNotRender - boolean if true, the graph wil not be re-rendered
   */
  removeDataSeries:function (serieIndex, doNotRender) {
    if (this.data.length > serieIndex) {
      this.data.splice(serieIndex, 1);     
      this.seriesNames.splice(serieIndex, 1);
      if (this.widget && !doNotRender) {     
        this.renderTo(this.selector)
      }
    }
    else {
      throw "This data set has only " + this.data.length + " elements.";
    }
  },

  /**
   * Sets the xaxis title
   * @param title - the x axis title as a string
   */
  setXAxisTitle:function (title) {
    this.cfg.axes.xaxis.label = title;
  },
  
  /**
   * Sets the yaxis title
   * @param title - the y axis title as a string
   */
  setYAxisTitle:function (title) {
    this.cfg.axes.yaxis.label = title;
  },


  /**
   * @event datapreload - fires before the data is loaded - if the handler returns false
   * the data will not be loaded, if it returns an object with a property called data,
   * then it will be used instead of the server data
   * @event datapostload - fires after the data is loaded
   */
  setData:function (data) {
    var status = this.fireEvent('datapreload', data);
    //one of the listeners returned false, stop the load
    if (status === false) {
      return false;
    }
    else if (typeof(status) == 'object' && status.data) {
      this.data = status.data;
    }
    else {
      this.data = data;
    }
    console.log(this.data);
    this.fireEvent("datapostload", data);
    return true;
  },

  /**
   * Returns the data assigned to the widget
   */
  getData:function () {
    return this.data;
  },


  /**
   * Configures the chart object before rendering. All subclasses should override
   * this method in order to add their specific configurations
   * @param <object> cfg - a configuration object for the diagram
   */
  configure:function (cfg) {
    if (!cfg) {
      cfg = {
        series: this.seriesNames
      };
    }
    this.cfg = jQuery.extend(this.cfg, cfg)
    return this.cfg;
  },

  /**
   * Renders the widget to a given DOM element
   * @event render - fires before the widget is rendered.
   * @event afterrender - fires after the widget was rendered
   * @param <string> selector - any valid CSS3 or Xpath selector
   */
  renderTo:function (selector) {
    this.callSuper(selector);
    this.fireEvent("render");

    this.selector = selector;
    jQuery(selector).html("");
    this.widget = jQuery.jqplot(Rj.getId(this.selector), this.data, this.configure())

    jQuery.jqplot.preDrawHooks.push(function (plot) {
      if (window.gritterZoomMessage !== true) {
        jQuery.gritter.add({
          title :'Diagram Tip',
          text  :'You can restore the zoom level to its initial value by double clicking inside the diagram.',
          sticky:false,
          time  :''
        });
        window.gritterZoomMessage = true;
      }
    })
    this.fireEvent("afterrender");

  }

})
