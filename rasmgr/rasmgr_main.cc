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
/
/**
 * SOURCE: rasmgr_main.cc
 *
 * MODULE: rasmgr
 * CLASS:
 *
 * PURPOSE:
 *   management of rasserver executables
 *
 * COMMENTS:
 * - FIXME: looks like a rasmgr slave still uses old comm scheme -- compatible?
 *
*/

#include "config.h"
#include "version.h"
#include <iostream>

#include "rasmgr.hh"
#include "rasmgr_config.hh"
#include "rasmgr_host.hh"
#include "rasmgr_dbm.hh"
#include "rasmgr_srv.hh"
#include "rasmgr_master.hh"
#include "rasmgr_rascontrol.hh"
#include "rasmgr_users.hh"
#include "ras_crypto.hh"
#include "rasmgr_localsrv.hh"
#include "rasmgr_error.hh"
#include "raslib/rminit.hh"

#ifndef COMPDATE
#error "Please specify the COMPDATE variable!"
/*
COMPDATE=`date +"%d.%m.%Y %H:%M:%S"`

and -DCOMPDATE="\"$(COMPDATE)\"" when compiling
*/
#endif

#define DEBUG_MAIN
#undef DEBUG_HH
#include "debug-srv.hh"

RMINITGLOBALS('S');

Configuration config;

HostManager         hostmanager;
DatabaseHostManager dbHostManager;
DatabaseManager     dbManager;
RasServerManager    rasManager;
MasterComm          masterCommunicator;
RasControl          rascontrol;
UserManager         userManager;
Authorization       authorization;
LocalServerManager  localServerManager;
RandomGenerator     randomGenerator;

void installSignalHandlers();

int main(int argc, char** argv, char** envp)
{
    SET_OUTPUT( true ); // enable debugging trace, if compiled so

    ENTER( "main." );

    cout << "rasmgr: rasdaman server manager tool. rasdaman "
         << RMANVERSION << " -- generated on " << COMPDATE << "." << std::endl
         << "Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009 Peter Baumann, rasdaman GmbH.\n"
         << "Rasdaman community is free software: you can redistribute it and/or modify "
         "it under the terms of the GNU General Public License as published by "
         "the Free Software Foundation, either version 3 of the License, or "
         "(at your option) any later version. \n"
         "Rasdaman community is distributed in the hope that it will be useful, "
         "but WITHOUT ANY WARRANTY; without even the implied warranty of "
         "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the "
         "GNU General Public License for more details. \n\n";

    if(testIsMessageDigestAvailable("MD5")==false)
    {
        RMInit::logOut<<"Error: Message Digest MD5 not available."<<std::endl;
        return RASMGR_RESULT_NO_MD5;
    }

    installSignalHandlers();

    bool result  = config.interpretArguments(argc,argv,envp);
    if (result == false)
        return RASMGR_RESULT_ILL_ARGS;

    if(config.isTestModus())
    {
        RMInit::logOut<<"rasmgr running in test modus ";
        VLOG <<", listening on port=" << config.getListenPort() << std::endl;
    }
    else
    {
        VLOG << " rasmgr running on " << config.getHostName() << ", listening on port " << config.getListenPort();
        VLOG << " with poll timeout " << config.getPollFrequency() << " seconds. ";
    }

    if(config.isTestModus()==false)
    {
        TALK( "hostname=" << config.getHostName() << ", publicHostname=" << config.getPublicHostName() );
        if(strcmp(config.getHostName(),config.getPublicHostName()) != 0)
        {
            VLOG <<"Advertised host name is "<<config.getPublicHostName()<<std::endl;
        }

        bool resultConfig = config.readConfigFile();
        TALK( "rasmgr::main: resultConfig=" << resultConfig );
        rascontrol.setConfigDirty( false );        // all changes to config up to now come from config file, do not require save

        int resultAuth = authorization.readAuthFile();
        TALK( "rasmgr::main: resultAuth=" << resultAuth );
        switch( resultAuth )
        {
        case RC_OK:
            TALK( "rasmgr::main: auth file ok, set state to not dirty." );
            rascontrol.setAuthDirty( false );   // auth file ok, so clean init state
            break;
        case ERRAUTHFNOTF:
            TALK( "rasmgr::main: auth file not found, loading defaults." );
            userManager.loadDefaults();
            // disabled because otherwise tons of new auth files are generated -- PB 2005-jul-02
            // rascontrol.setAuthDirty( true ); // auth file not present, write default
            break;
        case ERRAUTHFCORR:
            LEAVE( "rasmgr::main: auth file corrupt." );
            return RASMGR_RESULT_AUTH_CORRUPT;
            break;
        case ERRAUTHFWRHOST:
            LEAVE( "rasmgr::main: auth file for another host." );
            return RASMGR_RESULT_AUTH_OTHERHOST;
            break;
        case ERRAUTHFVERS:
            LEAVE( "rasmgr::main: auth file version mismatch." );
            return RASMGR_RESULT_AUTH_INCOMPAT;
            break;
        default:                // should not occur, internal enum mismatch
            LEAVE( "rasmgr::main: illegal auth file result code " << resultAuth << ", internal error." );
            return RASMGR_RESULT_INTERNAL;
            break;
        }

        try
        {
            TALK( "launching masterCommunicator.Run()..." );
            masterCommunicator.Run();       // central request handling loop
            TALK( "masterCommunicator.Run() done." );
        }
        catch(RCError& e)
        {
            char *errorMsg;
            e.getString(errorMsg);
            RMInit::logOut<<"Error: "<<errorMsg<<std::endl;
        }

// write the config file only on explicit rascontrol request "save"
// (and at that moment), or at rascontrol "exit" to a rescue file -- PB 2003-jun-06
#ifdef NEVER_AGAIN
        if(!config.saveConfigFile())
        {
            RMInit::logOut<<"Error saving configuration file."<<std::endl;
        }

        if(!authorization.saveAuthFile())
        {
            RMInit::logOut<<"Error saving user authorization file."<<std::endl;
        }
#endif
    }

    else if(config.isTestModus())
    {
        hostmanager.insertInternalHost();
        userManager.loadDefaults();
        masterCommunicator.Run();
    }

    RMInit::logOut <<"rasmgr terminated."<<std::endl;

    int retval = RASMGR_RESULT_OK;
    LEAVE( "main: leave. retval=" << retval );
    return retval;
} // main()

// danger: RMInit::logOut in interrupt???
// handler for SIGINT and SIGTERM = call for exit
void SigIntHandler(int sig)
{
    RMInit::logOut<<"rasmgr received terminate signal...";
    masterCommunicator.shouldExit();
}

void installSignalHandlers()
{
    signal (SIGINT, SigIntHandler);
    signal (SIGTERM, SigIntHandler);
    signal (SIGHUP, SIG_IGN);
    signal (SIGPIPE,SIG_IGN);
    signal (SIGTTOU,SIG_IGN); // no console, ei si?
}

// should be replaced by something cleaner, eventually
void exitbyerror(const char* text)
{
    perror(text);
    exit( RASMGR_EXIT_FAILURE );
}

char *strtolwr(char *string)// should be somewhere in the C-library, but can't find it
{
    char *t=string;
    for(; *t; t++)
    {
        if(*t>='A' && *t<='Z') *t|='a'-'A';
    }
    return string;
}

