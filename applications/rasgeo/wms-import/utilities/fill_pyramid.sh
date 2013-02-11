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
# Populate the pyramid levels associated to a specified rasdaman collection.
#
# SYNTAX
	ME="$( basename $0 )"
	ARG_TASPLIT='--tasplit'
	USAGE="
	usage: $ME <collName> [$ARG_TASPLIT]
	where
		<collName> 	must be an existing collection in rasdaman with an associated pyramid.
		$ARG_TASPLIT	split transaction into small units (saves main memory). 
	"

	# In case the usage changes, consequently adjust these values:
	MIN_ARGS=1
	MAX_ARGS=2
#
# DESCRIPTION
#       Given a precedently initialized WMS layer (empty pyramid creation and metadata push to
#	the database), this script is used to either populate the pyramid collections associated
#	to the baselayer, or to update their content in case the baselayer changed as well.
#	WMS layer metadata are meant to be fixed, so a change in the extent of a rasdaman collection
#	that is published as WMS layer shall prompt a new WMS layer creation.
# RETURN CODES
        RC_OK=0         # all went fine
        RC_ERROR=1      # something went wrong
#
# PRECONDITIONS
# 	- fillpyramid binary is installed
#	- the specified collname has been already initialized as WMS layer (init_wms.sh)
#	- rasgeo connectfile is set up in $HOME/.rasdaman/ (see rasgeo README file);
#       - Output of rasdaman SELECT still matches with "Result object ...".
#       - of course, rasdaman and postgres are up and running.
#
# TODO: 
#    ...
#
# --- DEFAULTS ------------------------------------------------------

# user / password for logging in to rasdaman
# (defined here so that they do not appear in command line)
USER=rasadmin
PASSWD=rasadmin

# Map types
GREY_COLLTYPE=GreySet
GREY_MDDTYPE=GreyImage
RGB_COLLTYPE=RGBSet
RGB_MDDTYPE=RGBImage
DEM_COLLTYPE=DoubleSet
DEM_MDDTYPE=DoubleImage

# load metadata db connection info (see ./rasgeo/README)
  CONNECT_FILE="$HOME/.rasdaman/rasconnect"
      HOST_KEY=host
    PGPORT_KEY=pgport
 RASDBNAME_KEY=rasdbname
PETADBNAME_KEY=petadbname
  PETAUSER_KEY=petauser
PETAPASSWD_KEY=petapassword

# --- END DEFAULTS --------------------------------------------------

# --- CONSTANTS -----------------------------------------------------
# --- do not change anything here unless you have a real clue

# required binaries
AWK="$( which gawk )" # see #295

IMPORT_BIN="$( which fillpyramid )"
ARG_COLLNAME='--collname'
ARG_MDDDOMAIN='--mdddomain'
ARG_MDDTYPE='--mddtype'
ARG_SCALELEVELS='--scalelevels'
ARG_USER='--user'
ARG_PASSWD='--passwd'

# known options for map types
MAPTYPE_GREY=GreySet
MAPTYPE_RGB=RGBSet
# aliases for fillpyramid
MAPTYPE_GREY_WMS=GREY
MAPTYPE_RGB_WMS=RGB
# aliases for initpyramid
MAPTYPE_GREY_INIT=gray8
MAPTYPE_RGB_INIT=rgb24

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
       TABLE_LAYERS=ps_layers
TABLE_PYRAMIDLEVELS=ps_pyramidlevels
# PS_COVERAGE
COVERAGE_ID=id
COVERAGE_NAME=name
# PS_CELLDOMAIN
CELLDOMAIN_COVERAGE=coverage
CELLDOMAIN_LO=lo
CELLDOMAIN_HI=hi
CELLDOMAIN_I=i
# PS_COVERAGE
COVERAGE_ID=id
COVERAGE_NAME=name
# PS_LAYER
LAYERS_LAYERID=layerid
LAYERS_NAME=name
# PS_PYRAMIDLEVELS
PYRAMIDLEVELS_LAYERID=layerid
PYRAMIDLEVELS_COLLECTIONNAME=collectionname
PYRAMIDLEVELS_SCALEFACTOR=scalefactor

# PSQL return values
PG_SELECT_NULL="(0 rows)"
  PG_SELECT_OK="(1 row)"

# --- END CONSTANTS -------------------------------------------------

# --- PARAMETER EVALUATION ------------------------------------------

# check whether the required tools are available
# i) installed
if [ ! -f "$IMPORT_BIN" ]; then 
	echo "$ME: ERROR: 'fillpyramid' not found, please install."
	exit $RC_ERROR
fi
if [ ! -f "$AWK" ]; then
  echo "$ME: ERROR: 'gawk' not found, please install."
  exit $RC_ERROR
fi

# ii) executable
if [ ! -x "$IMPORT_BIN" ]; then 
	echo "$ME: ERROR: $IMPORT_BIN is not executable."
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
echo -en "\n$ME: Parsing arguments... "
COLLNAME=$1
TASPLIT=''
if [ $# -eq $MAX_ARGS ]; then 
	if [ "$2" = "$ARG_TASPLIT" ]; then 
		TASPLIT="$2"
	else 
		echo "$ME: unknown argument '$2'."
		echo "$USAGE"
		exit $RC_ERROR
	fi
fi

# Connection params
   RAS_HOST=$(cat $CONNECT_FILE  | grep $HOST_KEY       | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
    PG_PORT=$(cat $CONNECT_FILE  | grep $PGPORT_KEY     | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
 RASDB_NAME=$(cat $CONNECT_FILE  | grep $RASDBNAME_KEY  | "$AWK" 'BEGIN { FS="=" }; { print $2 }')
PETADB_NAME="$(cat $CONNECT_FILE | grep $PETADBNAME_KEY | "$AWK" 'BEGIN { FS="=" }; { print $2 }')"
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

# Check if the associated  /WMS/ layer also exists, and retrieve the ID of the WMS layer
query="	SELECT $TABLE_LAYERS.$LAYERS_LAYERID, $TABLE_LAYERS.$LAYERS_NAME FROM $TABLE_LAYERS, $TABLE_PYRAMIDLEVELS
	WHERE $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_LAYERID = $TABLE_LAYERS.$LAYERS_LAYERID
	and $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_COLLECTIONNAME = '$COLLNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK" 1>/dev/null
if [ "$?" -ne 0 ]; then
	echo "$ME: ERROR: "$MAPNAME" already exists in $PETADB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
else 
	layerId=$( echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $5 };' )
	layerName=$( echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $7 };' )
	echo "$ME: Associated WMS layer: $layerName (ID #$layerId)."
fi

# --- END PARAMETER EVALUATION --------------------------------------
# --- ACTION --------------------------------------------------------

echo -n "$ME: Fetching dimensions of $COLLNAME... "

# Read the pixel dimensions:
query="	SELECT $CELLDOMAIN_LO, $CELLDOMAIN_HI FROM $TABLE_CELLDOMAIN, $TABLE_COVERAGE
	WHERE $CELLDOMAIN_COVERAGE = $TABLE_COVERAGE.$COVERAGE_ID 
	AND $TABLE_COVERAGE.$COVERAGE_NAME = '$COLLNAME'
	ORDER BY $CELLDOMAIN_I;"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK2" 1>/dev/null
if [ "$?" -eq 0 ]; then
	PIXEL_XMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $5 };' )
	PIXEL_XMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $7 };' )
	PIXEL_YMIN=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $8 };' )
	PIXEL_YMAX=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $10 };' )
	echo "read [$PIXEL_XMIN:$PIXEL_XMAX,$PIXEL_YMIN:$PIXEL_YMAX]"
else 
	echo 
	echo "$ME: ERROR while fetching pixel-domain information of $COLLNAME from $PETADB_NAME@$RAS_HOST:$PG_PORT."
	exit $RC_ERROR
fi

# Build up the levelstring 'pyramid_level_coll:factor':
query=" SELECT $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_COLLECTIONNAME, $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_SCALEFACTOR
	FROM $TABLE_PYRAMIDLEVELS, $TABLE_LAYERS
	WHERE $TABLE_PYRAMIDLEVELS.$PYRAMIDLEVELS_LAYERID = $TABLE_LAYERS.$LAYERS_LAYERID
	AND $TABLE_LAYERS.$LAYERS_NAME = '$layerName';"
levelsString=""	# argument for import executable: exclude baselayer from inputs: grep $COLLNAME_ instead of $COLLNAME.
while read line; do 
	pyramidName=$( echo "$line" | "$AWK" 'BEGIN {FS=" " }; { print $1 };' )
	pyramidFactor=$( echo "$line" | "$AWK" 'BEGIN {FS=" " }; { print $3 };' )
	echo "$ME: Found pyramid level $pyramidName with scale factor $pyramidFactor..."
	if [ "$levelsString" == "" ]; then 
		levelsString="$pyramidName:$pyramidFactor"
	else 
		levelsString="$levelsString;$pyramidName:$pyramidFactor"
	fi
done <<< "$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$PETADB_NAME"  | grep "$COLLNAME"_ )"

# Check type of collection and translate it to be compatible with import binary.
query="	SELECT $SETTYPES_TYPENAME FROM $TABLE_MDDCOLLNAMES, $TABLE_SETTYPES 
	WHERE $TABLE_MDDCOLLNAMES.$MDDCOLLNAMES_SETTYPEID = $TABLE_SETTYPES.$SETTYPES_SETTYPEID
	AND $MDDCOLLNAMES_COLLNAME = '$COLLNAME';"
ret=$( echo "$query" | psql -f - --single-transaction -h "$RAS_HOST" -p "$PG_PORT" "$RASDB_NAME" )
#
echo "$ret" | grep "$PG_SELECT_OK" 1>/dev/null
if [ "$?" -eq 0 ]; then
	MAPTYPE=$(  echo "$ret" | sed ':a;N;$!ba;s/\n/ /g' | "$AWK" 'BEGIN { FS=" " }; { print $3 };' )
	echo "$ME: Map is of type $MAPTYPE."
else 
	echo "$ME: ERROR: could not fetch data type from $RASDB_NAME."
	exit $RC_ERROR
fi
# standardise maptype keyword, with special care for initpyramid call
[[ "$MAPTYPE" = "$GREY_COLLTYPE" ]] && mddType="$GREY_MDDTYPE"
[[ "$MAPTYPE" = "$RGB_COLLTYPE"  ]] && mddType="$RGB_MDDTYPE"
[[ "$MAPTYPE" = "$DEM_COLLTYPE"  ]] && mddType="$DEM_MDDTYPE"
if [ "$mddType" == "" ]; then
	echo "$ME: $MAPTYPE is not a WMS supported map type (allowed types: $GREY_COLLTYPE, $RGB_COLLTYPE, $DEM_COLLTYPE)."
	exit $RC_ERROR
fi

# Now it ispossible to call the executable that populates/updates the pyramid content:
ARG_VERBOSE='-v'
echo "$ME: executing '$IMPORT_BIN $TASPLIT $ARG_VERBOSE $ARG_COLLNAME $COLLNAME $ARG_MDDDOMAIN [$PIXEL_XMIN:$PIXEL_XMAX,$PIXEL_YMIN:$PIXEL_YMAX] $ARG_MDDTYPE $mddType $ARG_SCALELEVELS $levelsString $ARG_USER $USER $ARG_PASSWD $PASSWD'"...
"$IMPORT_BIN" $TASPLIT $ARG_VERBOSE "$ARG_COLLNAME" "$COLLNAME" "$ARG_MDDDOMAIN" "[$PIXEL_XMIN:$PIXEL_XMAX,$PIXEL_YMIN:$PIXEL_YMAX]" $ARG_MDDTYPE $mddType $ARG_SCALELEVELS "$levelsString" $ARG_USER $USER $ARG_PASSWD $PASSWD

echo 
echo "$ME: done."
exit $RC_OK
# --- END ACTION --------------------------------------------------------
