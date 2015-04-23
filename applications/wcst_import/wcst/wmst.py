from abc import ABCMeta, abstractmethod


class WMSTRequest:
    """
    Generic class for WCST requests
    """
    __metaclass__ = ABCMeta
    SERVICE_PARAMETER = "service"
    SERVICE_VALUE = "WMS"
    VERSION_PARAMETER = "version"
    VERSION_VALUE = "1.3.0"
    REQUEST_PARAMETER = "request"

    def get_query_string(self):
        """
        Returns the query string that defines the WMST requests (the get parameters in string format)
        :rtype str
        """
        extra_params = ""
        for key, value in self._get_request_type_parameters().iteritems():
            extra_params += "&" + key + "=" + value
        return self.SERVICE_PARAMETER + "=" + self.SERVICE_VALUE + "&" + \
               self.VERSION_PARAMETER + "=" + self.VERSION_VALUE + "&" + \
               self.REQUEST_PARAMETER + "=" + self._get_request_type() + extra_params

    @abstractmethod
    def _get_request_type_parameters(self):
        """
        Returns the request specific parameters
        :rtype dict
        """
        pass

    @abstractmethod
    def _get_request_type(self):
        """
        Returns the request type
        :rtype str
        """
        pass


class WMSTFromWCSInsertRequest():
    def __init__(self, wcs_coverage_id, with_pyramids):
        """
        Class to insert a wcs coverage into wms. This is not a standard way in OGC but a custom method in the
        WMS service offered by rasdaman to allow for automatic insertion
        Constructor for the class

        :param str wcs_coverage_id: the coverage id to be used as a layer
        """
        self.wcs_coverage_id = wcs_coverage_id
        self.with_pyramids = with_pyramids

    def _get_request_type(self):
        """
        Returns the request type
        :rtype str
        """
        return self.__REQUEST_TYPE

    def _get_request_type_parameters(self):
        """
        Returns the request specific parameters
        :rtype dict
        """
        ret = {
            self.__COVERAGE_ID_PARAMETER: self.wcs_coverage_id,
            self.__WITH_PYRAMIDS_PARAMETER: str(self.with_pyramids)
        }
        return ret

    __REQUEST_TYPE = "InsertWCSLayer"
    __COVERAGE_ID_PARAMETER = "wcsCoverageId"
    __WITH_PYRAMIDS_PARAMETER = "withPyramids"


class WMSFromWCSDeleteRequest():
    """
    Class to delete a wcs coverage into wms. This is not a standard way in OGC but a custom method in the
    WMS service offered by rasdaman to allow for automatic insertion
    """

    def __init__(self, wcs_coverage_id, with_pyramids):
        """
        Class to delete a wcs coverage into wms. This is not a standard way in OGC but a custom method in the
        WMS service offered by rasdaman to allow for automatic deletion
        Constructor for the class

        :param str wcs_coverage_id: the coverage id to be used as a layer
        """
        self.wcs_coverage_id = wcs_coverage_id
        self.with_pyramids = with_pyramids

    def _get_request_type(self):
        """
        Returns the request type
        :rtype str
        """
        return self.__REQUEST_TYPE

    def _get_request_type_parameters(self):
        """
        Returns the request specific parameters
        :rtype dict
        """
        ret = {
            self.__COVERAGE_ID_PARAMETER: self.wcs_coverage_id
        }
        return ret

    __REQUEST_TYPE = "DeleteWCSLayer"
    __COVERAGE_ID_PARAMETER = "wcsCoverageId"