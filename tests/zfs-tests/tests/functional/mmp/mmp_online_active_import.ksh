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
#	Under no circumstances when MMP is active, should an active pool
#	with one hostid be importable by a host with a different hostid.
#
# STRATEGY:
#	1. Run ztest in the background with one hostid.
#	2. Set hostid to simulate a second node
#	3. Repeatedly attempt a `zpool import -f` on the pool created
#	   by ztest. `zpool import -f` should never succeed.
#	4. Repeatedly attempt a `zpool import` on the pool created
#	   by ztest. `zpool import` should never succeed.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/mmp/mmp.cfg

verify_runnable "both"
ZTESTPID=

function cleanup
{
	ls -l $TEST_BASE_DIR/mmp_vdevs | while read aline; do
		log_note $aline
	done

	zpool import -d $TEST_BASE_DIR/mmp_vdevs | while read aline; do
		log_note $aline
	done

	if [ -f $TEST_BASE_DIR/ztest.out ]; then
		log_note "======= Tail of of ztest.out: ======="
		tail -n 40 $TEST_BASE_DIR/ztest.out | while read aline; do
			log_note $aline
		done
		log_note "======= End of ztest.out: ======="
	fi

	if [ -f $TEST_BASE_DIR/import.out ]; then
		log_note "======= Contents of import.out: ======="
		cat $TEST_BASE_DIR/import.out | while read aline; do
			log_note $aline
		done
		log_note "======= End of import.out: ======="
	fi

	if [ -n "$ZTESTPID" ]; then
		if ps -p $ZTESTPID > /dev/null; then
			log_must kill -s 9 $ZTESTPID
			wait $ZTESTPID
		fi
	fi

	if poolexists ztest; then
                log_must zpool destroy ztest
        fi

	log_must rm -rf "$TEST_BASE_DIR/mmp_vdevs"

	set_spl_tunable spl_hostid $SPL_HOSTID_DEFAULT
}

log_assert "zpool import fails on active pool (MMP)"
log_onexit cleanup

log_must_not pgrep ztest

log_must mkdir "$TEST_BASE_DIR/mmp_vdevs"

log_note "Starting ztest in the background"

rm -f $TEST_BASE_DIR/ztest.out

export ZFS_HOSTID="$SPL_HOSTID1"
log_must eval "ztest -M -T 600 -t1 -k0 -VV -f $TEST_BASE_DIR/mmp_vdevs >> $TEST_BASE_DIR/ztest.out 2>&1 &"
ZTESTPID=$!
if ! ps -p $ZTESTPID > /dev/null; then
	log_fail "ztest failed to start"
fi
unset ZFS_HOSTID

if ! set_spl_tunable spl_hostid $SPL_HOSTID2 ; then
	log_fail "Failed to set spl_hostid to $SPL_HOSTID2"
fi

log_must sleep 5

EXPECTED_MESSAGE="Export the pool on the other system"

typeset cmd="zpool import -f -d $TEST_BASE_DIR/mmp_vdevs/ ztest 2>&1"
for i in {1..10}; do
	log_must eval "$cmd | tee $TEST_BASE_DIR/import.out | grep \"$EXPECTED_MESSAGE\""
done

cmd="zpool import -d $TEST_BASE_DIR/mmp_vdevs/ ztest 2>&1"
for i in {1..10}; do
	log_must eval "$cmd | tee $TEST_BASE_DIR/import.out | grep \"$EXPECTED_MESSAGE\""
done

log_pass "zpool import fails on active pool (MMP) passed"
