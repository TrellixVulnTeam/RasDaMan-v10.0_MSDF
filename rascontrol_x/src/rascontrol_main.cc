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
 * Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014 Peter Baumann / rasdaman GmbH.
 *
 * For more information please see <http://www.rasdaman.org>
 * or contact Peter Baumann via <baumann@rasdaman.com>.
 */

#include <boost/cstdlib.hpp>

#include "../../common/src/logging/easylogging++.hh"
#include "../../common/src/crypto/crypto.hh"

#include "config.h"
#include "version.h"

#include "rascontrolconfig.hh"
#include "usercredentials.hh"
#include "rascontrolconstants.hh"
#include "rascontrol.hh"



#ifndef RMANVERSION
#error "Please specify RMANVERSION variable!"
#endif

#ifndef COMPDATE
#error "Please specify the COMPDATE variable!"
/*
COMPDATE=`date +"%d.%m.%Y %H:%M:%S"`

and -DCOMPDATE="\"$(COMPDATE)\"" when compiling
*/
#endif

_INITIALIZE_EASYLOGGINGPP

int main(int argc, char** argv)
{
    //Default logging configuration
    easyloggingpp::Configurations defaultConf;
    defaultConf.setToDefault();
    easyloggingpp::Loggers::reconfigureAllLoggers(defaultConf);
    easyloggingpp::Loggers::disableAll();

    rascontrol::RasControlConfig config;
    rascontrol::UserCredentials userCredentials;

    try
    {

        if(config.parseCommandLineParameters(argc, argv)==false)
        {
            return EXIT_FAILURE;
        }

        if(!config.getLogConfigFile().empty())
        {
            std::string configFile=config.getLogConfigFile();
            easyloggingpp::Configurations conf(configFile.c_str());
            easyloggingpp::Loggers::reconfigureAllLoggers(conf);
        }

        if(!config.isQuietMode())
        {
            std::cout << "rascontrol: rasdaman server remote control utility. rasdaman " << RMANVERSION << " -- generated on " << COMPDATE << "." << std::endl;
            std::cout << " Copyright 2003, 2004, 2005, 2006, 2007, 2008, 2009 Peter Baumann rasdaman GmbH." << std::endl
                      << "Rasdaman community is free software: you can redistribute it and/or modify "
                      "it under the terms of the GNU General Public License as published by "
                      "the Free Software Foundation, either version 3 of the License, or "
                      "(at your option) any later version. \n"
                      "Rasdaman community is distributed in the hope that it will be useful, "
                      "but WITHOUT ANY WARRANTY; without even the implied warranty of "
                      "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the "
                      "GNU General Public License for more details. \n\n";
            std::cout << "This software contains software which is in the public domain:" << std::endl;
            std::cout << "- openssl 0.96c (C) 1998-2002 The OpenSSL Project, (C) 1995-1998 Eric A. Young, Tim J. Hudson" << std::endl;
        }

        if(config.isHelpRequested())
        {
            config.displayHelp();
            return EXIT_SUCCESS;
        }

        if(common::Crypto::isMessageDigestAvailable(DEFAULT_DIGEST)==false)
        {
            std::cout<<"Error: Message Digest "<<DEFAULT_DIGEST<<" not available."<<std::endl;
            return EXIT_FAILURE;
        }

        if(config.getLoginMode() == rascontrol::RasControlConfig::LGIINTERACTIV)
        {
            userCredentials.interactiveLogin();
        }
        else
        {
            userCredentials.environmentLogin();
        }

        rascontrol::RasControl control(config, userCredentials);

        control.start();

    }
    catch(std::exception& ex)
    {
        std::cout << ex.what() << std::endl;
        return EXIT_FAILURE;

    }
    catch(...)
    {
        std::cout << "RasControl failed for an unknown reason."
                  << " Please contact the administrator with instructions to reproduce the failure" << std::endl;
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}