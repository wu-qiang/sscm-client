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
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/policy-provision.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/policy-provision.sh $SCRIPTS_DIR
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/policy-test.sh $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/policy-test.sh $SCRIPTS_DIR
echo "cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/kauctl $SCRIPTS_DIR"
cp -f $SSCM_BUILD_DIR/sscm-client/scripts/sbas/kauctl $SCRIPTS_DIR

echo "chmod +x $SCRIPTS_DIR/*"
chmod +x $SCRIPTS_DIR/*
echo "ls -l $SCRIPTS_DIR"
ls -l $SCRIPTS_DIR

echo "$GPG_SCRIPT --init-keyring"
$GPG_SCRIPT --init-keyring
echo "$GPG_SCRIPT --get-authority-names"
$GPG_SCRIPT --get-authority-names
#echo "$GPG_SCRIPT --test"
#$GPG_SCRIPT --test

echo "Execute: $SCRIPTS_DIR/authorities-generator.sh"
$SCRIPTS_DIR/authorities-generator.sh
echo "ls -ld $ATTESTATION_AUTHORITY_FILE"
ls -ld $ATTESTATION_AUTHORITY_FILE
echo "cat $ATTESTATION_AUTHORITY_FILE"
cat $ATTESTATION_AUTHORITY_FILE

echo "Execute: $SCRIPTS_DIR/provision-grafeas.sh \"${GRAFEAS_SERVER_ADDRESS}:${GRAFEAS_SERVER_PORT}\""
$SCRIPTS_DIR/provision-grafeas.sh "${GRAFEAS_SERVER_ADDRESS}:${GRAFEAS_SERVER_PORT}"

echo "Execute: $SCRIPTS_DIR/policy-provision.sh"
$SCRIPTS_DIR/policy-provision.sh
echo "Execute: $SCRIPTS_DIR/policy-test.sh"
$SCRIPTS_DIR/policy-test.sh

