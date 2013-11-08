#!/bin/bash
#
# ~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=
# This file is part of rasdaman community.
#
# Rasdaman community is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Rasdaman community is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with rasdaman community.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009 Peter Baumann /
# rasdaman GmbH.
#
# For more information please see <http://www.rasdaman.org>
# or contact Peter Baumann via <baumann@rasdaman.com>.
# ~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=
#
# Initialize pyramid levels and fill out WMS metadata (in the database) of existing 
# rasdsaman collection. 
#
# Warning: prompts for password if psql not configured to avoid it!
#  e.g. ident or trust for rasdaman and petascope db users
#
# SYNTAX
# Scale factors of the pyramid levels which will be created on top of the base layer ('1').
# Baselayer (factor1) must be already be existing in RASBASE.
	LEVELS_STRING='2:4:8:16:32:64:128:256'
	PYRAMID_ARG='-l'
	HOST_ARG='-h'
	PORT_ARG='-p'
	CONNFILE_ARG='-c'
	ME="$( basename $0 )"
	USAGE="
	usage: $ME <layerName> <collName> <crs> [$PYRAMID_ARG <pyramidLevels>] [$HOST_ARG <host>] [$PORT_ARG <port>] [$CONNFILE_ARG <path_to_rasconnect>]
	where
		<layerName>	the arbitrary name for the /new/ WMS layer;
		<collName> 	must be an existing collection in rasdaman (but not already a published WMS coverage);
		<crs> 		the 2D Coordinate Reference System and must be expressed as AUTHORITY:CODE (e.g. EPSG:4326);
		<pyramidLevels> must be a string of colon-separated scale factors, one for each pyramid. 
				Default is '$LEVELS_STRING'. Each scale factor must be twice the previous one.
		<host:port> 	of the WMS (->Petascope): important for for pluggin the WMS service into client softwares [default localhost:8080]. 
				Argument are considered if this is the first WMS layer that is added, 
				hence no WMS service has previously been defined.
		<path_to_rasconnect>	metadata db connection info (see ./rasgeo/README),
				defaults to $HOME/.rasdaman/rasconnect
	"
	# In case the usage changes, consequently adjust these values:
	MIN_ARGS=3
	MAX_ARGS=11
#
# DESCRIPTION
#       Given an existing 2D coverage in rasdaman, the script fetches its metadata
#	(extents and resolution) then calls initpyramid to initialize the empty pyramid
#       layers in RASBASE. Then the WMS required metadata is filled out in the
#       metadata database.
#
# RETURN CODES
        RC_OK=0         # all went fine
        RC_ERROR=1      # something went wrong
#
# PRECONDITIONS
# 	- initpyramid binary is installed
#	- no map with name mapname defined, the collection with name collname must exist;
#	- rasgeo connectfile is set up in $HOME/.rasdaman/ (see rasgeo README file);
#       - gdaltransform utility is installed;
#       - Output of rasdaman SELECT still matches with "Result object ...".
#       - of course, rasdaman and postgres are up and running.
#
# CHANGE HISTORY
#       2003-jul-30     P.Baumann       created
#       2003-oct-20     P.Baumann       use initpyramid instead of rginitmap
#					enforce different map and collection names (rasogc!)
#					make new rastools.meta and rasogc.cfg readable for all
#       2008-may-02     P.Baumann       metadata now in database
#       2012-jun-01     pcampalani	Backporting for Petascope: automatic fetch of collection metadata
#                                       and petascopedb sync.
#       2013-aug-29     A.Beccati       connection file as a parameter to allow calling script from other user context or from a web server profile
#
# TODO: 
#    - add option to cutomize the style: currently the layer are limited to RGB and Grey sets, "as is".
#    - add possibility to publish a 2D slice out of a nD collection as WMS layer.
#    - check consitency of user specified CRS?
#    - what if X resolution != Y resolution?
#    - ...
#
# --- DEFAULTS ------------------------------------------------------
# --- values here can (and should) be adjusted to local choices -----

# (defined here so that they do not appear in command line)
# Added also to dbconnect file so that no hardcoded values are used
# TODO: keeping them initialized here for backward compatibility,
# remove from there (they'll be overwritten by connect file) as soon as
# new connect file is deployed officially (might require migration,
# warning already added)
USER=rasadmin 
PASSWD=rasadmin

# script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# load metadata db connection info (see ./rasgeo/README)
  CONNECT_FILE="$HOME/.rasdaman/rasconnect"
      HOST_KEY=host
    PGPORT_KEY=pgport
 RASDBNAME_KEY=rasdbname
   RASUSER_KEY=rasuser # user for RASBASE (not used here)
 RASPASSWD_KEY=raspassword # user password for RASBASE (not used here)
      USER_KEY=rasloginuser # user for logging in to rasdaman
    PASSWD_KEY=rasloginpassword # password for logging in to rasdaman
PETADBNAME_KEY=petadbname
  PETAUSER_KEY=petauser
PETAPASSWD_KEY=petapassword
# --- END DEFAULTS --------------------------------------------------

# --- CONSTANTS -----------------------------------------------------
# --- do not change anything here unless you have a real clue

# required binaries
INITPROG="initpyramid"
WGET="$( which wget )"
AWK="$( which gawk )" # see #295
DC="$( which dc )"

# temp file names
TEMPFILE=`mktemp /tmp/$ME.output.XXXXXX`

# number of digits (precision) used for floating point computation (resolution)
PRECISION=10

# known options for map types
GREY_COLLTYPE=GreySet
RGB_COLLTYPE=RGBSet
DEM_COLLTYPE=DoubleSet
# aliases for fillpyramid
MAPTYPE_GREY_WMS=GREY
MAPTYPE_RGB_WMS=RGB
MAPTYPE_DEM_WMS=DEM
# aliases for initpyramid
MAPTYPE_GREY_INIT=gray8
MAPTYPE_RGB_INIT=rgb24
MAPTYPE_DEM_INIT=dem32

# Tables to be used to fetch metadata in rasdaman
TABLE_MDDCOLLNAMES=ras_mddcollnames
    TABLE_SETTYPES=ras_settypes
# RAS_MDDCOLLNAMES
MDDCOLLNAMES_SETTYPEID=settypeid
MDDCOLLNAMES_COLLNAME=mddcollname
#RAS_SETTYPES
SETTYPES_SETTYPEID=settypeid
SETTYPES_TYPENAME=settypename

# Tables to be updated in the metadata database
     TABLE_COVERAGE=ps_coverage
   TABLE_CELLDOMAIN=ps_celldomain
   TABLE_CRSDETAILS=ps_crsdetails
     TABLE_SERVICES=ps_services
 TABLE_SERVICELAYER=ps_servicelayer
       TABLE_LAYERS=ps_layers
       TABLE_STYLES=ps_styles
TABLE_PYRAMIDLEVELS=ps_pyramidlevels
# PS_COVERAGE
COVERAGE_ID=id
COVERAGE_NAME=name
# PS_CELLDOMAIN
CELLDOMAIN_COVERAGE=coverage
CELLDOMAIN_LO=lo
CELLDOMAIN_HI=hi
CELLDOMAIN_I=i
# PS_CRSDETAILS
CRSDETAILS_COVERAGE=coverage
CRSDETAILS_LOW1=low1
CRSDETAILS_HIGH1=high1
CRSDETAILS_LOW2=low2
CRSDETAILS_HIGH2=high2
# PS_SERVICES
SERVICES_SERVICEID=serviceid
SERVICES_NAME=name
# PS_SERVICELAYER
SERVICELAYER_LAYERSEQ=layerseq
# PS_LAYER
LAYERS_LAYERID=layerid
LAYERS_NAME=name
LAYERS_TITLE=title
LAYERS_SRS=srs
LAYERS_AUTHORITY=authority
LAYERS_LATLONBOXXMIN=latlonboxxmin
LAYERS_LATLONBOXXMAX=latlonboxxmax
LAYERS_LATLONBOXYMIN=latlonboxymin
LAYERS_LATLONBOXYMAX=latlonboxymax
LAYERS_BBOXXMIN=bboxxmin
LAYERS_BBOXXMAX=bboxxmax
LAYERS_BBOXYMIN=bboxymin
LAYERS_BBOXYMAX=bboxymax
LAYERS_ATTRIBUTIONURL=attributionurl
LAYERS_ATTRIBUTIONTITLE=attributiontitle
LAYERS_LOGOWIDTH=logowidth
LAYERS_LOGOHEIGHT=logoheight
LAYERS_LOGOFORMAT=logoformat
LAYERS_LOGOURL=logourl
LAYERS_FEATUREURL=featureurl
LAYERS_RESOLUTION=resolution
LAYERS_MAPTYPE=maptype
# PS_STYLES
STYLES_NAME=name
STYLES_TITLE=title
STYLES_ABSTRACT=abstract
STYLES_LEGENDWIDTH=legendwidth
STYLES_LEGENDHEIGHT=legendheight
STYLES_LEGENDURL=legendurl
STYLES_SHEETURL=sheeturl
STYLES_RASQLOP=rasqlop
# PS_PYRAMIDLEVELS
PYRAMIDLEVELS_LAYERID=layerid
PYRAMIDLEVELS_COLLECTIONNAME=collectionname
PYRAMIDLEVELS_SCALEFACTOR=scalefactor

# KEYWORDS
          AXISTYPE_X=x
     DEFAULT_KEYWORD=default
   UNDEFINED_KEYWORD=undefined
    STANDARD_KEYWORD=standard
     MAPNAME_KEYWORD=mapname
ATTRIBUTIONURL_TEMPL="http://www.rasdaman.com/{$MAPNAME_KEYWORD}/about.html"
    DEFAULT_LAYERSEQ=0	# table ps_servicelayer
DEFAULT_AVAILABILITY=2
     WMS_SERVICENAME='default_WMS'
      PYRAMID_SUFFIX='pyr' # suffix which is appended to the baselayer name for pyramids
# WGS84 CRS identifiers for gdaltransform
               WGS84='EPSG:4326'
         QL_MAXCELLS=max_cells
              QL_OUT='Result element 1:'

# WMS service
PETASCOPE_HOST='localhost'
PETASCOPE_PORT=8080
WMS_PATH='petascope/wms'
WMS_VERSION='1.1.0'
WMS_RELOADCAPABILITIES='reloadcapabilities'
JPEG_FORMAT='image/jpeg'		# For supported image output formats see petascope.wms.WmsRequest.java::WMSREQ_FORMAT_*
PNG_FORMAT='image/png'			# Formats are specified as MIME types (OGC 01-068r3)
TIFF_FORMAT='image/tiff'
#CAPXML_FORMAT='application/vnd.ogc.wms_xml'	# grep "application/" <rasdama>/applications/petascope/src/main/java/petascope/wms/ -r
#EXPXML_FORMAT='application/vnd.ogc.se_xml'
#IOW_FORMAT='application/vnd.ogc.se_inimage'
#BLANK_FORMAT='application/vnd.ogc.se_blank'
# Format list must use colons ';' as separator, see  petascope.wms.WmsConfig.java::buildWMSFormatsList()
WMS_FORMATS="$JPEG_FORMAT;$PNG_FORMAT;$TIFF_FORMAT"  
WMS_SERVICE_INSERT="$SCRIPT_DIR/add_wms_service.sh"
# PSQL return values
  PG_INSERT_OK=".* 0 1"
PG_SELECT_NULL="(0 .*)"
  PG_SELECT_OK="(1 .*)"
 PG_SELECT_OK2="(2 .*)"

# HTTP code
HTTP_OK_CODE=200

# --- END CONSTANTS -------------------------------------------------

# --- PARAMETER EVALUATION ------------------------------------------

# check whether the required tools are available
# i) installed
if [ ! -f "$WGET" ]; then 
	echo "$ME: ERROR: 'wget' not found, please install."
	exit $RC_ERROR
fi
if [ ! -f "$WMS_SERVICE_INSERT" ]; then 
	echo "$ME: ERROR: 'initpyramid' not found, please install."
	exit $RC_ERROR
fi
if [ ! -f "$DC" ]; then
  echo "$ME: ERROR: 'dc' not found, please install."
  exit $RC_ERROR
fi
if [ ! -f "$AWK" ]; then
  echo "$ME: ERROR: 'gawk' not found, please install."
  exit $RC_ERROR
fi

# ii) executable
if [ ! -x "$WGET" ]; then 
	echo "$ME: ERROR: $WGET is not executable."
	exit $RC_ERROR
fi
if [ ! -x "$WMS_SERVICE_INSERT" ]; then
	echo "$ME: ERROR: $WMS_SERVICE_INSERT is not executable."
	exit $RC_ERROR
fi
if [ ! -x "$DC" ]; then
  echo "$ME: ERROR: $DC is not executable."
  exit $RC_ERROR
fi
if [ ! -x "$AWK" ]; then
  echo "$ME: ERROR: $AWK is not found executable."
  exit $RC_ERROR
fi

# check number of parameters
if [ $# -lt $MIN_ARGS -o $# -gt $MAX_ARGS ]
then
	echo "$USAGE"
	exit $RC_ERROR
fi

# get parameters and check them
MAPNAME=$1
COLLNAME=$2
CRS=$3
echo -en "\n$ME: Parsing arguments... "
while [ $# -gt 0 ]; do 
	case "$1" in
          $PYRAMID_ARG) LEVELS_STRING="$2";  shift;;
 	  $HOST_ARG)    PETASCOPE_HOST="$2"; shift;;
 	  $PORT_ARG)    PETASCOPE_PORT="$2"; shift;;
 	  $CONNFILE_ARG)   CONNECT_FILE="$2" ; shift;;
	esac
        shift
done
PETASCOPEWMS_URL="http://$PETASCOPE_HOST:$PETASCOPE_PORT/$WMS_PATH"

if [ ! -d $RMANHOME ]
then
	echo "$ME: ERROR: environment variable RMANHOME does not point to the rasdaman/rasgeo directory: $RMANHOME"
	exit $RC_ERROR
fi

# Connection params
    RAS_HOST=$(cat $CONNECT_FILE  | grep $HOST_KEY       | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
     PG_PORT=$(cat $CONNECT_FILE  | grep $PGPORT_KEY     | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  RASDB_NAME=$(cat $CONNECT_FILE  | grep $RASDBNAME_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  RASUSER=$(cat $CONNECT_FILE  | grep $RASUSER_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  RASPASSWD=$(cat $CONNECT_FILE  | grep $RASPASSWD_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')

  #TODO: remove check and defaults after deprecation of old format, rename without T
  TUSER=$(cat $CONNECT_FILE  | grep $USER_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  TPASSWD=$(cat $CONNECT_FILE  | grep $PASSWD_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  
  #TODO: remove check and defaults after deprecation of old format
  if [ -z "$TUSER" ] ; then
    echo "$ME: WARNING: Parameter $USER_KEY missing from connect file: $CONNECT_FILE , please update it!"
    echo "$ME: Using default $USER_KEY = $USER"
  else
    USER="$TUSER"
  fi

  #TODO: remove check and defaults after deprecation of old format
  if [ -z "$TPASSWD" ] ; then
    echo "$ME: WARNING: Parameter $PASSWD_KEY missing from connect file: $CONNECT_FILE , please update it!"
    echo "$ME: Using default $PASSWD_KEY = $PASSWD"
  else
    PASSWD="$TPASSWD"
  fi


 PETADB_NAME="$(cat $CONNECT_FILE  | grep $PETADBNAME_KEY | "$AWK" 'BEGIN { FS="=" }; { print $2 }')"
    PETAUSER=$(cat $CONNECT_FILE  | grep $PETAUSER_KEY   | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
  PETAPASSWD=$(cat $CONNECT_FILE  | grep $PETAPASSWD_KEY | "$AWK" 'BEGIN { FS="=" }; { print $2 }')

echo "$ME: Using databases {$RASDB_NAME,$PETADB_NAME}@$RAS_HOST:$PG_PORT."

# Check existence of rasdaman collection 
collExists=0
while read coll; do 
	if [ "$coll" = "$COLLNAME" ]; then collExists=1; fi
done <<< "$( rasql -q "select r from RAS_COLLECTIONNAMES as r" --out string | grep "Result object" | "$AWK" 'BEGIN { FS=" "}; { print $4 };' )"
if [ "$collExists" -eq 0 ]; then
	echo "$ME: ERROR: "$COLLNAME" must be an existing collection in $RASDB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
fi

# Check if the /WMS/ layer does not already exist:
query="SELECT $LAYERS_LAYERID FROM $TABLE_LAYERS WHERE $LAYERS_NAME='$MAPNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_NULL" 1>/dev/null
if [ "$?" -ne 0 ]; then
	echo "$ME: ERROR: "$MAPNAME" already exists in $PETADB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
fi

# Eventually, check if the rasdaman collection has not already been used as baselayer for a WMS coverage:
query="	SELECT $TABLE_LAYERS.$LAYERS_NAME FROM $TABLE_LAYERS, $TABLE_PYRAMIDLEVELS
	WHERE $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_LAYERID = $TABLE_LAYERS.$LAYERS_LAYERID
	AND $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_COLLECTIONNAME = '$COLLNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_NULL" 1>/dev/null
if [ "$?" -ne 0 ]; then
	wmsName=$( echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $3 };' )
	echo "$ME: ERROR: "$COLLNAME" was already published as WMS layer in $PETADB_NAME@$RAS_HOST:$PG_PORT, as '$wmsName'."
	exit $RC_ERROR
fi


# --- END PARAMETER EVALUATION --------------------------------------
# --- FUNCTIONS --------------------------------------

# Deletes previously inserted pyramid collections in RASBASE after failures in metadata insertion:
function rollback {
	echo "$ME: Rollback: "
	while read coll; do 
		echo -n "  Deleting $coll... "
		rasql -q "drop collection $coll" --user $USER --passwd $PASSWD 1>/dev/null
		echo "Done."
	done <<< "$( rasql -q "select r from RAS_COLLECTIONNAMES as r" --out string | grep "$COLLNAME"_"$PYRAMID_SUFFIX" | "$AWK" 'BEGIN { FS=" "}; { print $4 };' )"
	echo "$ME: Done."
}

# --- ACTION --------------------------------------------------------

echo "$ME: Fetching metadata of $COLLNAME... "

# Fetch metadata of the collection:
query="	SELECT $SETTYPES_TYPENAME FROM $TABLE_MDDCOLLNAMES, $TABLE_SETTYPES 
	WHERE $TABLE_MDDCOLLNAMES.$MDDCOLLNAMES_SETTYPEID = $TABLE_SETTYPES.$SETTYPES_SETTYPEID
	AND $MDDCOLLNAMES_COLLNAME = '$COLLNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$RASDB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK" 1>/dev/null
if [ "$?" -eq 0 ]; then
	MAPTYPE=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $3 };' )
else 
	echo "$ME: ERROR: could not fetch data type from $RASDB_NAME."
	exit $RC_ERROR
fi
# standardise maptype keyword, with special care for initpyramid call
if [ "$MAPTYPE" == "$GREY_COLLTYPE" ]; then
	INITMAP_MAPTYPE=$MAPTYPE_GREY_INIT
	MAPTYPE=$GREY_COLLTYPE
	PETAMAPTYPE="$MAPTYPE_GREY_WMS"
elif [ "$MAPTYPE" == "$RGB_COLLTYPE" ]; then
	INITMAP_MAPTYPE=$MAPTYPE_RGB_INIT
	MAPTYPE=$RGB_COLLTYPE
	PETAMAPTYPE="$MAPTYPE_RGB_WMS"
elif [ "$MAPTYPE" == "$DEM_COLLTYPE" ]; then
	INITMAP_MAPTYPE=$MAPTYPE_DEM_INIT
	MAPTYPE=$DEM_COLLTYPE
	PETAMAPTYPE="$MAPTYPE_DEM_WMS"
else
	echo "$ME: $MAPTYPE is not a WMS supported map type (allowed types: $GREY_COLLTYPE, $RGB_COLLTYPE, $DEM_COLLTYPE)."
	exit $RC_ERROR
fi

# Read bounding-box from the metadata (still ps_crsdetails)
query="	SELECT $CRSDETAILS_LOW1, $CRSDETAILS_LOW2, $CRSDETAILS_HIGH1, $CRSDETAILS_HIGH2
	FROM $TABLE_CRSDETAILS, $TABLE_COVERAGE
	WHERE $TABLE_CRSDETAILS.$CRSDETAILS_COVERAGE = $TABLE_COVERAGE.$COVERAGE_ID
	AND $TABLE_COVERAGE.$COVERAGE_NAME = '$COLLNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK" 1>/dev/null
if [ "$?" -eq 0 ]; then
	XMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $9 };' )
	YMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $11 };' )
	XMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $13 };' )
	YMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $15 };' )
else 
	echo "$ME: ERROR while fetching bounding box information of $COLLNAME from $PETADB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
fi

# Read the pixel dimensions:
query="
	SELECT $CELLDOMAIN_LO, $CELLDOMAIN_HI FROM $TABLE_CELLDOMAIN, $TABLE_COVERAGE
	WHERE $CELLDOMAIN_COVERAGE = $TABLE_COVERAGE.$COVERAGE_ID 
	AND $TABLE_COVERAGE.$COVERAGE_NAME = '$COLLNAME'
	ORDER BY $CELLDOMAIN_I;
"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK2" 1>/dev/null
if [ "$?" -eq 0 ]; then
	PIXEL_XMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $5 };' )
	PIXEL_XMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $7 };' )
	PIXEL_YMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $8 };' )
	PIXEL_YMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $10 };' )
else 
	echo "$ME: ERROR while fetching pixel-domain information of $COLLNAME from $PETADB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
fi
# resolution (it is assumed to be equal in both X and Y directions)
XMIN_DC=$( echo $XMIN | sed s/-/_/ )
XMAX_DC=$( echo $XMAX | sed s/-/_/ )
WIDTH=$(( $PIXEL_XMAX - $PIXEL_XMIN + 1 ))
RES=$( dc -e "$PRECISION k $XMAX_DC $XMIN_DC - $WIDTH / p" )
# Finished to fetch the required metadata.

echo "Done."
echo "$ME: adding map $MAPNAME / collection $COLLNAME, bbox is [ $XMIN : $XMAX, $YMIN : $YMAX ] with resolution $RES, CRS $CRS"

# perform pyramid initialization in rasdasman database
export RMANPROTOCOL=RNP
echo "$ME: executing '$INITPROG --user $USER --passwd $PASSWD --mapname ${COLLNAME}_$PYRAMID_SUFFIX --maptype $INITMAP_MAPTYPE -x $PIXEL_XMIN -y $PIXEL_YMIN -X $PIXEL_XMAX -Y $PIXEL_YMAX --levels $LEVELS_STRING'"...
$INITPROG --user $USER --passwd $PASSWD --mapname "$COLLNAME"_$PYRAMID_SUFFIX --maptype $INITMAP_MAPTYPE \
    -x $PIXEL_XMIN -y $PIXEL_YMIN -X $PIXEL_XMAX -Y $PIXEL_YMAX --levels "$LEVELS_STRING" | tee $TEMPFILE || echo -n "return code $?..."
export RMANPROTOCOL=
if [ "`grep Error $TEMPFILE 2>/dev/null`" == "" ]
then
	echo "$ME: map creation successfully done."
else
	echo "$ME: ERROR: cannot initialize rasdaman map."
	exit $RC_ERROR
fi

# Parse all the new inserted layers in rasdasman database to update the metadata later on
PYRAMID=$( "$AWK" '/Creating collection:/ { print $3; }' < $TEMPFILE )

# set rasql op specific for this
if [ "$MAPTYPE" == "$GREY_COLLTYPE" ]
then
	RASQLOP="standard * { 1c, 1c, 1c}"
elif [ "$MAPTYPE" == "$RGB_COLLTYPE" ]
then
	RASQLOP="standard"
elif [ "$MAPTYPE" == "$DEM_COLLTYPE" ]
then
	# parse the max_value of the collection so that the servlet does not need to find it at every request:
	maxValue="$( rasql -q "select $QL_MAXCELLS(x) from $COLLNAME as x" --out string | 
			grep "$QL_OUT" | "$AWK" 'BEGIN { FS=" " }; { print $4 };' )"	
	RASQLOP="(char)(255*standard/$maxValue)*{1c,1c,1c}"
else	# has been checked earlier, but we want to be sure
	echo "$ME: $MAPTYPE is not a WMS supported map type (allowed types: $GREY_COLLTYPE, $RGB_COLLTYPE, $DEM_COLLTYPE)."
	rollback
	exit $RC_ERROR
fi

# compute latlon coordinates of (GK!) bbox
XMIN_LATLON=$( echo $XMIN $YMIN | gdaltransform -s_srs $CRS -t_srs $WGS84 | "$AWK" '{ print $1 }' )
YMIN_LATLON=$( echo $XMIN $YMIN | gdaltransform -s_srs $CRS -t_srs $WGS84 | "$AWK" '{ print $2 }' )
XMAX_LATLON=$( echo $XMAX $YMAX | gdaltransform -s_srs $CRS -t_srs $WGS84 | "$AWK" '{ print $1 }' )
YMAX_LATLON=$( echo $XMAX $YMAX | gdaltransform -s_srs $CRS -t_srs $WGS84 | "$AWK" '{ print $2 }' )

# Export variables to open session with psql
export PGUSER="$PETAUSER"
export PGPASSWORD="$PETAPASSWD"

#############################
#      UPDATE METADATA      #
#############################
echo "$ME: Update WMS metadata in $PETADB_NAME@$RAS_HOST:$PG_PORT :"

# If the WMS service is not in the database, create it with default values (otherwise check its ID)
echo -n "$ME: Checking existence of $WMS_SERVICENAME inside $TABLE_SERVICES... "
while [ "$serviceID" = "" ]; do
	query="SELECT $SERVICES_SERVICEID FROM $TABLE_SERVICES WHERE $SERVICES_NAME='$WMS_SERVICENAME';"
	ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
	#
	echo "$ret" | grep "$PG_SELECT_OK" 1>/dev/null
	if [ "$?" -eq 0 ]; then
		serviceID=$( echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $3 };' )
	else 
		echo -n "NO --> Add it to the database... "
		$WMS_SERVICE_INSERT --name "$WMS_SERVICENAME" --title "$WMS_SERVICENAME WMS Service" --host $PETASCOPE_HOST --port $PETASCOPE_PORT --path $WMS_PATH --formats "$WMS_FORMATS" --availability $DEFAULT_AVAILABILITY  --baselayer-name "$MAPNAME"
		if [ "$?" -eq "$RC_ERROR" ]; then
			echo -n "$ME: ERROR during insertion.\nAbort procedure."
			rollback
			exit $RC_ERROR
		fi
	fi
done
echo " Done (ID#$serviceID)."

# Add new layer to the metadata database
echo -n "$ME: Inserting $MAPNAME layer into $TABLE_LAYERS... "
queryLayers="INSERT INTO $TABLE_LAYERS (\
	$LAYERS_NAME, $LAYERS_TITLE, $LAYERS_SRS, $LAYERS_AUTHORITY, \
	  $LAYERS_LATLONBOXXMIN, $LAYERS_LATLONBOXXMAX, $LAYERS_LATLONBOXYMIN, $LAYERS_LATLONBOXYMAX,\
            $LAYERS_BBOXXMIN, $LAYERS_BBOXXMAX, $LAYERS_BBOXYMIN, $LAYERS_BBOXYMAX, \
	      $LAYERS_ATTRIBUTIONURL, $LAYERS_ATTRIBUTIONTITLE, \
                $LAYERS_LOGOWIDTH, $LAYERS_LOGOHEIGHT, $LAYERS_LOGOFORMAT, $LAYERS_LOGOURL, $LAYERS_FEATUREURL, $LAYERS_RESOLUTION, $LAYERS_MAPTYPE) \
       VALUES (\
	'$MAPNAME', '$MAPNAME', '$CRS', '$UNDEFINED_KEYWORD', \
	  $XMIN_LATLON, $XMAX_LATLON, $YMIN_LATLON, $YMAX_LATLON, \
	    $XMIN, $XMAX, $YMIN, $YMAX, \
	      '$( echo $ATTRIBUTIONURL_TEMPL | sed s/{$MAPNAME_KEYWORD}/$MAPNAME/g )', '$UNDEFINED_KEYWORD', \
	        0, 0, '$UNDEFINED_KEYWORD', '$UNDEFINED_KEYWORD', '$UNDEFINED_KEYWORD', $RES, '$PETAMAPTYPE' ) \
       RETURNING $LAYERS_LAYERID;"
ret=$( echo "$queryLayers" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )

echo "$ret" | grep "$PG_INSERT_OK" 1>/dev/null
if [ "$?" -ne 0 ]; then 
	echo "$ME: ERROR while updating $TABLE_LAYERS table of $PETADB_NAME@$RAS_HOST:$PG_PORT. Postgres response:"
	echo "$ret"
	rollback
	exit $RC_ERROR
else 
	layerID=$( echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $3 };' )
fi
echo "Done."

# INSERT INTO ps_servicelayer
queryServiceLayer="INSERT INTO $TABLE_SERVICELAYER (\
	$SERVICES_SERVICEID, $LAYERS_LAYERID, $SERVICELAYER_LAYERSEQ)\
	VALUES (\
	$serviceID, $layerID, $DEFAULT_LAYERSEQ );"
# INSERT INTO ps_style
queryStyles="INSERT INTO $TABLE_STYLES (\
	$LAYERS_LAYERID, $STYLES_NAME, $STYLES_TITLE, $STYLES_ABSTRACT, \
	  $STYLES_LEGENDWIDTH, $STYLES_LEGENDHEIGHT, $STYLES_LEGENDURL, \
	    $STYLES_SHEETURL, $STYLES_RASQLOP) \
       VALUES (\
	$layerID, '$STANDARD_KEYWORD', 'layer $MAPNAME, style $STANDARD_KEYWORD', '$UNDEFINED_KEYWORD', \
	  0, 0, '$UNDEFINED_KEYWORD',
	    '$UNDEFINED_KEYWORD', '$RASQLOP' );"
# INSERT INTO ps_pyramidlevels
# [petascope.wms.commander.Globals.java] 
#  "Scale factor relative to the original map. The original map has a scale factor of 1 by definition, 
#   upper pyramid layers have a factor greater than 1; no factor should appear more than once, 
#   otherwise WMS behavior is undefined (mandatory)."
# Baselayer metadata
queriesPyramids="
	INSERT INTO $TABLE_PYRAMIDLEVELS (\
		$LAYERS_LAYERID, $PYRAMIDLEVELS_COLLECTIONNAME, $PYRAMIDLEVELS_SCALEFACTOR )\
	       VALUES (\
		$layerID, '$COLLNAME', 1 );
"
# Pyramids
RES=$( echo "$LEVELS_STRING" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=":" }; { print $1 }' )
TOT_INSERTS=1
for COLLECTION in $PYRAMID; do
	echo "$ME: Pyramid level $COLLECTION to have scale factor $RES... "

	queriesPyramids+="INSERT INTO $TABLE_PYRAMIDLEVELS (\
		$LAYERS_LAYERID, $PYRAMIDLEVELS_COLLECTIONNAME, $PYRAMIDLEVELS_SCALEFACTOR )\
	       VALUES (\
		$layerID, '$COLLECTION', $RES );"
	# Update resolution
	RES=$( dc -e "$PRECISION k $RES 2 * n" )
	# Update inserts 
	TOT_INSERTS=$(( $TOT_INSERTS + 1 ))
done

# Group queries in a unique transaction
echo -n "$ME: Adding styles and pyramids metadata... "
ret=$( echo "$queryServiceLayer $queryStyles $queriesPyramids" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
echo "Done."

# Total of ServiceLayer + NPyramidLevels + Style = N+2 inserts.
TOT_INSERTS=$(( TOT_INSERTS + 2 ))
if [ $( echo "$ret" | grep "$PG_INSERT_OK" | wc -l ) -ne $TOT_INSERTS ]; then
	echo "$ME: ERROR while updating $TABLE_SERVICELAYER, $TABLE_STYLES and $TABLE_PYRAMIDLEVELS tables of $PETADB_NAME@$RAS_HOST:$PG_PORT. Postgres response:"
	echo "'$ret'"
	# Manually remove previously inserted layer metadata
	echo "$ME: Removing "$COLLNAME" layer metadata... "
	query="DELETE FROM $TABLE_LAYERS WHERE $LAYERS_LAYERID=$layerID"
	echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME"
	#Manually rollback layers query and delete collectins in RASBASE
	rollback
	exit $RC_ERROR
fi
echo "Done."

# reload new capabilities file into rasogc
echo "$ME: reloading capabilities into rasgeo URL=$PETASCOPEWMS_URL..."
ReloadCapReq="$PETASCOPEWMS_URL?request=$WMS_RELOADCAPABILITIES&service=wms&version=$WMS_VERSION"
ReloadCapRespCode=$( $WGET --spider -S "$ReloadCapReq" 2>&1 | grep "HTTP/" | "$AWK" '{print $2}')
if [[ "$ReloadCapRespCode" -ne $HTTP_OK_CODE ]]; then
	echo "$ME: ERROR while reloading WMS capabilities. HTTP code: $ReloadCapRespCode."
	echo "$ME: Try reloading them manually: \"$ReloadCapReq\""
	exit $RC_ERROR
else 
	echo "$ME: Database $PETADB_NAME has been updated and WMS servlet ($PETASCOPEWMS_URL) refreshed."
fi

echo
echo "$ME: done."
exit $RC_OK
# --- END ACTION --------------------------------------------------------
