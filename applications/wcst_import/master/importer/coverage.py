from master.importer.axis_subset import AxisMetadata
from master.importer.slice import Slice
from master.provider.metadata.axis import Axis
from master.provider.metadata.grid_axis import GridAxis
from collections import OrderedDict


class Coverage:
    def __init__(self, coverage_id, slices, range_fields, crs, pixel_data_type, tiling=None):
        """
        Class to represent a coverage that is created in a recipe containing the minimum amount of information
        form which we can extrapolate the whole gmlcov
        :param str coverage_id: the id of the coverage
        :param list[Slice] slices: a list of slices defining the coverage
        :param list[RangeTypeField] range_fields: the range fields for the coverage
        :param str crs: the crs of the coverage
        :param str pixel_data_type: the type of the pixel in gdal format
        :param str tiling: the tiling string to be passed to rasdaman if one is chosen
        """
        self.coverage_id = coverage_id
        self.slices = slices
        self.range_fields = range_fields
        self.crs = crs
        self.pixel_data_type = pixel_data_type
        self.tiling = tiling

    def get_insert_axes(self):
        """
        Returns all the axes for this subset
        :rtype: dict[Axis, GridAxis]
        """
        axes = OrderedDict()
        for axis_subset in self.slices[0].axis_subsets:
            axes[axis_subset.axis] = axis_subset.grid_axis
        return axes

    def get_update_axes(self):
        """
        Returns the axes for the slices that are bound to the data (e.g. Lat and Long for a 2-D raster)
        :rtype: dict[Axis, GridAxis]
        """
        axes = OrderedDict()
        for axis_subset in self.slices[0].axis_subsets:
            if axis_subset.data_bound:
                axes[axis_subset.axis] = axis_subset.grid_axis
        return axes