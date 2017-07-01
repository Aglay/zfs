#!/bin/ksh -p
#
# CDDL HEADER START
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
# CDDL HEADER END
#

#
# Copyright (c) 2017 by Lawrence Livermore National Security, LLC.
#

# DESCRIPTION:
#	Verify import behavior for inactive (but not exported pools)
#
# STRATEGY:
#	1. Create a zpool
#	2. Verify safeimport=off and hostids match (no activity check)
#	3. Verify safeimport=off and hostids differ (no activity check)
#	4. Verify safeimport=on and hostids match (no activity check)
#	5. Verify safeimport=on and hostids differ (activity check)
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/mmp/mmp.cfg
. $STF_SUITE/tests/functional/mmp/mmp.kshlib

verify_runnable "both"

function cleanup
{
	default_cleanup_noexit
	log_must set_spl_tunable spl_hostid $SPL_HOSTID_DEFAULT
}

log_assert "safeimport=on|off activity checks"
log_onexit cleanup

# 1. Create a zpool
log_must set_spl_tunable spl_hostid $SPL_HOSTID1
default_setup_noexit $DISK

# 2. Verify safeimport=off and hostids match (no activity check)
log_must zpool set safeimport=off $TESTPOOL

for opt in "" "-f"; do
	log_must zpool export -F $TESTPOOL

	SECONDS=0
	log_must zpool import $opt $TESTPOOL
	if [[ $SECONDS -gt $ZPOOL_IMPORT_DURATION ]]; then
		log_fail "unexpected activity check (${SECONDS}s)"
	fi
done

# 3. Verify safeimport=off and hostids differ (no activity check)
log_must zpool export -F $TESTPOOL
log_must set_spl_tunable spl_hostid $SPL_HOSTID2

SECONDS=0
log_mustnot zpool import $TESTPOOL
if [[ $SECONDS -gt $ZPOOL_IMPORT_DURATION ]]; then
	log_fail "unexpected activity check (${SECONDS}s)"
fi

SECONDS=0
log_must zpool import -f $opt $TESTPOOL
if [[ $SECONDS -gt $ZPOOL_IMPORT_DURATION ]]; then
	log_fail "unexpected activity check (${SECONDS}s)"
fi

# 4. Verify safeimport=on and hostids match (no activity check)
log_must zpool set safeimport=on $TESTPOOL
log_must zpool export $TESTPOOL
log_must set_spl_tunable spl_hostid $SPL_HOSTID1
log_must zpool import $TESTPOOL

for opt in "" "-f"; do
	log_must zpool export -F $TESTPOOL

	SECONDS=0
	log_must zpool import $opt $TESTPOOL
	if [[ $SECONDS -gt $ZPOOL_IMPORT_DURATION ]]; then
		log_fail "unexpected activity check (${SECONDS}s)"
	fi
done

# 5. Verify safeimport=on and hostids differ (activity check)
log_must zpool export -F $TESTPOOL
log_must set_spl_tunable spl_hostid $SPL_HOSTID2

SECONDS=0
log_mustnot zpool import $TESTPOOL
if [[ $SECONDS -lt $ZPOOL_IMPORT_DURATION ]]; then
	log_fail "expected activity check (${SECONDS}s)"
fi

SECONDS=0
log_must zpool import -f $TESTPOOL
if [[ $SECONDS -lt $ZPOOL_IMPORT_DURATION ]]; then
	log_fail "expected activity check (${SECONDS}s)"
fi

log_pass "safeimport=on|off activity checks passed"
