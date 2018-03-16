#!/bin/bash

# These come from Wercker environment
# GPG_HOMEDIR
# GPG_ATTESTATION_AUTHORITY
# GPG_PASSPHRASE

SIGN_RESULT=1
VERIFY_RESULT=1

init() {
  if [ -z "$WERCKER_CACHE_DIR" ]; then
    printf "Variable WERCKER_CACHE_DIR is not set.  Exiting the script.\n"
    exit 1
  fi

  if [ ! -d "$WERCKER_CACHE_DIR" ]; then
    printf "Directory $WERCKER_CACHE_DIR does not exist.  Exiting the script.\n"
    exit 1
  fi

  if [ ! -d "$GPG_HOMEDIR" ]; then
    #echo "Creating $GPG_HOMEDIR"
    mkdir $GPG_HOMEDIR
    chmod 600 $GPG_HOMEDIR
    #ls -laF $WERCKER_CACHE_DIR
    #ls -laF $GPG_HOMEDIR
    #echo "Creating a pair of new keys in new dir"
    gpg --homedir $GPG_HOMEDIR --quick-generate-key --batch --passphrase $GPG_PASSPHRASE --yes $GPG_AUTHORITY_NAME 2> /dev/null
    gpg --homedir $GPG_HOMEDIR -k $GPG_AUTHORITY_NAME 2> /dev/null
    chmod 600 $GPG_HOMEDIR
  else
    #echo "$GPG_HOMEDIR exists"
    # Wercker somehow resets the permission bits on $GPG_HOMEDIR everytime this script is called from the pipeline
    # so we need to change it back to 600 to avoid the gpg permission WARNING
    chmod 600 $GPG_HOMEDIR
    #gpg --homedir $GPG_HOMEDIR -k --keyid-format short --with-colons $GPG_AUTHORITY_NAME
    gpg --homedir $GPG_HOMEDIR -k $GPG_AUTHORITY_NAME 2>&1> /dev/null
    if ! [ $? -eq 0 ]; then
      # no keys found so create a new key pair
      echo "Creating a pair of new keys"
      gpg --homedir $GPG_HOMEDIR --quick-generate-key --batch --passphrase $GPG_PASSPHRASE --yes $GPG_AUTHORITY_NAME 2> /dev/null
      gpg --homedir $GPG_HOMEDIR -k --with-colons 2> /dev/null
    fi
  fi
}

