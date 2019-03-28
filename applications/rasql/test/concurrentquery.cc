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
#include "version.h"
#include "config.h"

#include "globals.hh"

#ifdef EARLY_TEMPLATE
#define __EXECUTABLE__
#include "raslib/template_inst.hh"
#endif

#include "rasodmg/transaction.hh"
#include "rasodmg/database.hh"

// needed to configure logging
#include "loggingutils.hh"

#include <iostream>
#include <vector>
#include <pthread.h>

const unsigned int THREAD_NO = 2;

void* query_thread(void *ptr);

void* query_thread(void *ptr)
{
    auto threadId = *reinterpret_cast<unsigned int*>(ptr);
    LINFO << "running thread " << threadId;

    r_Database db;
    r_Transaction ta{&db};

    db.set_servername("localhost", 7001);
    db.set_useridentification("rasguest", "rasguest");
    db.open("RASBASE");

    ta.begin(r_Transaction::read_only);
    r_Set< r_Ref_Any > result_set;
    r_OQL_Query query("select avg_cells(c) from test_rgb as c");

    LINFO << "executing query...";
    r_oql_execute(query, result_set, &ta);
    ta.commit();

    db.close();

    LINFO << "thread done " << threadId;

    pthread_exit(0);
}

INITIALIZE_EASYLOGGINGPP

int main(int ac, char** av)
{
    common::LogConfiguration logConf(string(CONFDIR), CLIENT_LOG_CONF);
    logConf.configClientLogging();
    logConf.getConfig().set(el::Level::Info, el::ConfigurationType::Format, "%datetime - %msg");
    el::Loggers::getLogger("default")->configure(logConf.getConfig());

    std::vector<pthread_t> threads(THREAD_NO);
    std::vector<unsigned int> threadIds(THREAD_NO);

    for (unsigned int i = 0; i < THREAD_NO; i++)
    {
        threadIds[i] = i;
        pthread_create(&threads[i], NULL, query_thread, &threadIds[i]);
    }
    for (unsigned int i = 0; i < THREAD_NO; i++)
    {
        pthread_join(threads[i], NULL);
    }

    return 0;
}