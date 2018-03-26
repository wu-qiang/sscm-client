#!/bin/bash

#
# Set up scripts needed for demo env
#

if [ -z "$SSCM_BUILD_DIR" ] ; then
    echo "SSCM_BUILD_DIR not set! Exiting."
    exit 1
fi

if [ -z "$SCRIPTS_DIR" ] ; then
    echo "SCRIPTS_DIR not set! Exiting."
    exit 1
fi

echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/pgp/gpg-script.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/pgp/gpg-script.sh $SCRIPTS_DIR
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/sbas-check.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/sbas-check.sh $SCRIPTS_DIR
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/grafeas/provision-grafeas.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/grafeas/provision-grafeas.sh $SCRIPTS_DIR
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/authorities-generator.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/authorities-generator.sh $SCRIPTS_DIR

echo "chmod +x $SCRIPTS_DIR/*"
chmod +x $SCRIPTS_DIR/*
echo "ls -ld $WERCKER_CACHE_DIR/*.sh"
ls -ld $WERCKER_CACHE_DIR/*.sh

echo "Execute: $SSCM_BUILD_DIR/sscm-client/scripts/grafeas/provision-grafeas.sh"
#$SSCM_BUILD_DIR/sscm-client/scripts/grafeas/provision-grafeas.sh
echo "Execute: $SSCM_BUILD_DIR/sscm-client/scripts/sbas/authorities-generator.sh"
#$SSCM_BUILD_DIR/sscm-client/scripts/sbas/authorities-generator.sh

echo "$GPG_SCRIPT --init-keyring"
$GPG_SCRIPT --init-keyring
echo "$GPG_SCRIPT --get-authority-names"
$GPG_SCRIPT --get-authority-names
echo "$GPG_SCRIPT --test"
$GPG_SCRIPT --test

