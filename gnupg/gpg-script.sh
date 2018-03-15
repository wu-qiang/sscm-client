#!/bin/bash

GPG_HOME=$WERCKER_CACHE_DIR/gpghome
KEY_UID="sscm@oracle.com"
KEY_PASSPHRASE="passphrase"
SIGN_RESULT="1"
VERIFY_RESULT="1"

init() {
  if [ ! -d "$GPG_HOME" ]; then
    #echo "Creating $GPG_HOME"
    mkdir $GPG_HOME
    chmod 600 $GPG_HOME
    ls -laF $WERCKER_CACHE_DIR
    ls -laF $GPG_HOME
    #echo "Creating a pair of new keys in new dir"
    gpg --homedir $GPG_HOME --quick-generate-key --batch --passphrase $KEY_PASSPHRASE --yes $KEY_UID 2> /dev/null
    gpg --homedir $GPG_HOME -k $KEY_UID 2> /dev/null
    chmod 600 $GPG_HOME
  else
    #echo "$GPG_HOME exists"
    # Wercker somehow resets the permission bits on $GPG_HOME everytime this script is called from the pipeline
    # so we need to change it back to 600 to avoid the gpg permission WARNING
    chmod 600 $GPG_HOME
    #gpg --homedir $GPG_HOME -k --keyid-format short --with-colons $KEY_UID
    gpg --homedir $GPG_HOME -k $KEY_UID 2> /dev/null
    if ! [ $? -eq 0 ]; then
      # no keys found so create a new key pair
      #echo "Creating a pair of new keys"
      gpg --homedir $GPG_HOME --quick-generate-key --batch --passphrase $KEY_PASSPHRASE --yes $KEY_UID 2> /dev/null
      gpg --homedir $GPG_HOME -k --with-colons 2> /dev/null
    fi
  fi
}

# Sign a string, base64 encode the result and return it
gpg_sign() {
  local str="$1"
  #echo "signing $str"
  local signature=$(echo -n "$str" | gpg --homedir $GPG_HOME -u $KEY_UID --armor --sign --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null)
  if [ $? -eq 0 ]; then
    SIGN_RESULT=0
    # output the signature
    echo -n "$signature" | base64
  fi
}

gpg_verify() {
  local encodedSig="$1"
  local original_text="$2"
  local result=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null)
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null
  gpg --homedir $GPG_HOME -k --keyid-format short $KEY_UID  2> /dev/null
  if [ $? -eq 0 ]; then
    if [ "$result" == "$original_text" ]; then  
      printf "Signature is both valid and matched\n"
      VERIFY_RESULT=$?
    else
      printf "Signature does not match\n"
    fi
  fi
}

gpg_get_public_key_id() {
  # key's short id is the last 8 hex digits of its finger print
  gpg --homedir $GPG_HOME -k --no-tty --with-colons $KEY_UID  2> /dev/null | grep pub:u:2048:1:|cut -c 22-29
}

init
#if [ $# -eq 0 ]; then
#  gpg_get_public_key_id
if [ $# -eq 1 ]; then
  gpg_sign "$1"
  exit $SIGN_RESULT
elif [ $# -eq 2 ]; then
  gpg_verify "$1" "$2"
  exit $VERIFY_RESULT
fi
