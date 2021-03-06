#!/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2017, loli10K. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/cli_root/zpool_create/zpool_create.shlib

#
# DESCRIPTION:
#	'zpool attach -o ashift=<n> ...' should work with different ashift
#	values.
#
# STRATEGY:
#	1. Create various pools with different ashift values.
#	2. Verify 'attach -o ashift=<n>' works only with allowed values.
#

verify_runnable "global"

function cleanup
{
	poolexists $TESTPOOL1 && destroy_pool $TESTPOOL1
	log_must rm -f $disk1
	log_must rm -f $disk2
}

log_assert "zpool attach -o ashift=<n>' works with different ashift values"
log_onexit cleanup

disk1=$TEST_BASE_DIR/$FILEDISK0
disk2=$TEST_BASE_DIR/$FILEDISK1
log_must mkfile $SIZE $disk1
log_must mkfile $SIZE $disk2

typeset ashifts=("9" "10" "11" "12" "13" "14" "15" "16")
for ashift in ${ashifts[@]}
do
	for cmdval in ${ashifts[@]}
	do
		log_must zpool create -o ashift=$ashift $TESTPOOL1 $disk1
		verify_ashift $disk1 $ashift
		if [[ $? -ne 0 ]]
		then
			log_fail "Pool was created without setting ashift " \
			    "value to $ashift"
		fi
		# ashift_of(attached_disk) <= ashift_of(existing_vdev)
		if [[ $cmdval -le $ashift ]]
		then
			log_must zpool attach -o ashift=$cmdval $TESTPOOL1 \
			    $disk1 $disk2
			verify_ashift $disk2 $ashift
			if [[ $? -ne 0 ]]
			then
				log_fail "Device was attached without " \
				    "setting ashift value to $ashift"
			fi
		else
			log_mustnot zpool attach -o ashift=$cmdval $TESTPOOL1 \
			    $disk1 $disk2
		fi
		# clean things for the next run
		log_must zpool destroy $TESTPOOL1
		log_must zpool labelclear $disk1
		# depending on if we expect to have failed the 'zpool attach'
		if [[ $cmdval -le $ashift ]]
		then
			log_must zpool labelclear $disk2
		else
			log_mustnot zpool labelclear $disk2
		fi
	done
done

typeset badvals=("off" "on" "1" "8" "17" "1b" "ff" "-")
for badval in ${badvals[@]}
do
	log_must zpool create $TESTPOOL1 $disk1
	log_mustnot zpool attach $TESTPOOL1 -o ashift=$badval $disk1 $disk2
	log_must zpool destroy $TESTPOOL1
	log_must zpool labelclear $disk1
	log_mustnot zpool labelclear $disk2
done

log_pass "zpool attach -o ashift=<n>' works with different ashift values"
