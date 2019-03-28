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
* Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009 Peter Baumann /
rasdaman GmbH.
*
* For more information please see <http://www.rasdaman.org>
* or contact Peter Baumann via <baumann@rasdaman.com>.
*/

#include "cliententry.hh"
#include "raslib/parseparams.hh"
#include "qlparser/qtdata.hh"
#include "mddmgr/mddobj.hh"
#include "mddmgr/mddcoll.hh"
#include "mddmgr/mddcolliter.hh"
#include "tilemgr/tile.hh"
#include <logging.hh>
#include <cstring>

ClientTblElt::ClientTblElt(const char *clientText, unsigned long client) : clientId(client)
{
    creationTime = static_cast<long unsigned int>(time(NULL));

    clientIdText = new char[strlen(clientText) + 1];
    strcpy(clientIdText, clientText);

    baseName = new char[5];
    strcpy(baseName, "none");

    userName = new char[8];
    strcpy(userName, "unknown");

    clientParams = new r_Parse_Params();
    clientParams->add("exactformat", &exactFormat, r_Parse_Params::param_type_int);
}


ClientTblElt::~ClientTblElt()
{
    releaseTransferStructures();
    delete[] clientIdText;
    delete[] baseName;
    delete[] userName;
    delete[] transferFormatParams;
    delete[] storageFormatParams;
    delete clientParams;
}


void
ClientTblElt::release()
{
    if (currentUsers == 0)
    {
        LWARNING << "Warning: releasing a non-active client.";
    }
    currentUsers--;
    lastActionTime = static_cast<long unsigned int>(time(NULL));
}

void
ClientTblElt::releaseTransferStructures()
{
    // delete the transfer iterator
    if (transferCollIter)
    {
        LTRACE << "release transferCollIter";
        delete transferCollIter;
        transferCollIter = 0;
    }

    // delete transfer data
    if (transferData)
    {
        LTRACE << "release transferData";
        // delete list elements
        for (auto it = transferData->begin(); it != transferData->end(); it++)
            if (*it)
            {
                (*it)->deleteRef();
                (*it) = 0;
            }
        delete transferData;
        transferData = 0;
    }

    // delete the transfer collection
    // the transferData will check objects because of the bugfix.  therefore the objects may deleted only after the check.
    if (transferColl)
    {
        LTRACE << "release transferColl";
        transferColl->releaseAll();
        delete transferColl;
        transferColl = 0;
    }

    // delete transfer data iterator
    if (transferDataIter)
    {
        LTRACE << "release transferDataIter";
        delete transferDataIter;
        transferDataIter = 0;
    }

    // delete the temporary PersMDDObj
    if (assembleMDD)
    {
        LTRACE << "release assembleMDD";
        delete assembleMDD;
        assembleMDD = 0;
    }

    // delete the transfer MDDobj
    if (transferMDD)
    {
        LTRACE << "release transferMDD";
        delete transferMDD;
        transferMDD = 0;
    }

    // vector< Tile* >* transTiles;
    if (transTiles)
    {
        LTRACE << "release transTiles";
        // Tiles are deleted by the MDDObject owing them.
        // release( transTiles->begin(), transTiles->end() );
        delete transTiles;
        transTiles = 0;
    }

    // vector< Tile* >::iterator* tileIter;
    if (tileIter)
    {
        LTRACE << "release tileIter";
        delete tileIter;
        tileIter = 0;
    }

    // delete deletable tiles
    if (deletableTiles)
    {
        LTRACE << "release deletableTiles";

        for (auto it = deletableTiles->begin(); it != deletableTiles->end(); it++)
            delete *it;
        delete deletableTiles;
        deletableTiles = 0;
    }

    // delete persistent MDD collections
    if (persMDDCollections)
    {
        LTRACE << "release persMDDCollections";
        for (auto it = persMDDCollections->begin(); it != persMDDCollections->end(); it++)
            if (*it)
            {
                (*it)->releaseAll();
                delete *it;
            }

        delete persMDDCollections;
        persMDDCollections = 0;
    }

    // transfer compression
    if (encodedData != NULL)
    {
        free(encodedData);
        encodedData = NULL;
        encodedSize = 0;
    }

#ifdef RMANBENCHMARK
    // Attention: taTimer is deleted in either commitTA() or abortTA().

    if (evaluationTimer)
    {
        delete evaluationTimer;
    }
    evaluationTimer = 0;

    if (transferTimer)
    {
        delete transferTimer;
    }
    transferTimer = 0;
#endif
}