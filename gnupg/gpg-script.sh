#!/bin/bash

GPG_HOME=$WERCKER_CACHE_DIR/gnupg
KEY_UID="sscm@oracle.com"
KEY_PASSPHRASE="passphrase"
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

  if [ ! -d "$GPG_HOME" ]; then
    #echo "Creating $GPG_HOME"
    mkdir $GPG_HOME
    chmod 600 $GPG_HOME
    #ls -laF $WERCKER_CACHE_DIR
    #ls -laF $GPG_HOME
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
    gpg --homedir $GPG_HOME -k $KEY_UID 2>&1> /dev/null
    if ! [ $? -eq 0 ]; then
      # no keys found so create a new key pair
      echo "Creating a pair of new keys"
      gpg --homedir $GPG_HOME --quick-generate-key --batch --passphrase $KEY_PASSPHRASE --yes $KEY_UID 2> /dev/null
      gpg --homedir $GPG_HOME -k --with-colons 2> /dev/null
    fi
  fi
}

# Sign a string, base64 encode the result and return it
gpg_sign() {
  local str="$1"
  #echo "signing $str"
  #local out_file=$(mktemp)
  #if [ -e $out_file ]
  #then
  #  rm $out_file
  #fi
  echo "$str" | gpg -q --no-verbose --no-tty --batch --homedir $GPG_HOME -u $KEY_UID --armor --sign --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2>/dev/null | base64 -w 0
  if [ $? -eq 0 ]; then
    SIGN_RESULT=0
    # output the signature
    #echo "BASE64_ENCODED_SIGNATURE:::"`base64 -w 0 $out_file`":::BASE64_ENCODED_SIGNATURE"
    #rm $out_file
  fi
}

gpg_verify() {
  local encodedSig="$1"
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --verify
  if [ $? -eq 0 ]; then
    #if [ "$result" == "$original_text" ]; then
      #printf "Signature is both valid and matched\n"
      VERIFY_RESULT=$?
    #else
    #  printf "Signature does not match\n"
    #fi
  fi
}

gpg_verify_and_match() {
  local encodedSig="$1"
  #local original_text="$2"
  #local result=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null)
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null
  #gpg --homedir $GPG_HOME -k --keyid-format short $KEY_UID  2> /dev/null
  if [ $? -eq 0 ]; then
    #if [ "$result" == "$original_text" ]; then
      #printf "Signature is both valid and matched\n"
      VERIFY_RESULT=$?
    #else
    #  printf "Signature does not match\n"
    #fi
  fi
}

gpg_get_public_key_id() {
  # key's short id is the last 8 hex digits of its finger print
  gpg --homedir $GPG_HOME -k --no-tty --with-colons $KEY_UID  2> /dev/null | grep pub:u:2048:1:|cut -c 22-29
}

gpg_key_id_from_base64_encoded_signature() {
  local encodedSig="$1"
  local key_id=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID -q --no-tty --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2>&1)
echo "key id:[$key_id]"
  # key's short id is the last 8 hex digits of its finger print
}

gpg_signed_data_from_base64_encoded_signature() {
  local encodedSig="$1"
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE 2> /dev/null
  # key's short id is the last 8 hex digits of its finger print
  #local in_file=$(mktemp)
  #local out_file=$(mktemp)
  #echo "temp files: $in_file & $out_file"
  #echo "$encodedSig" | base64 --decode > $in_file
  #echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --pinentry-mode loopback --passphrase $KEY_PASSPHRASE
  #gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --batch --output $out_file $in_file
  #gpg --homedir $GPG_HOME -u $KEY_UID --decrypt --batch -o $out_file --pinentry-mode loopback --passphrase $KEY_PASSPHRASE
}

print_usage() {
  printf "Command usage for $0:\n"
  printf "==================================\n"
  printf "$0 -sign <key_uid> \"<string_to_be_signed>\"\n"
  printf "Sign a string using the key stored under the key_uid(e.g. sscm_attestation_auth@oracle.com).\n\n"

  printf "$0 -verify \"<base64_encoded_signature>\"\n"
  printf "Base64 decode the signature and verify.\n\n"

  printf "$0 -get_key_id \"<base64_encoded_signature>\"\n"
  printf "Get the short ID(last 8 Hex digits of the key's finger print) of the key that was used to sign the provided signature.\n\n"

  printf "$0 -get_signed_data \"<base64_encoded_signature>\"\n"
  printf "Get the original data from the encoded signature\n\n"
}

rm -rf $GPG_HOME
init
if [ $# -lt 2 -o $# -gt 3 ]
then
  print_usage
elif [ $# -eq 2 ]
then
  if [ $1 == "-verify" ]
  then
    gpg_verify "$2"
    exit $VERIFY_RESULT
  elif [ $1 == "-get_key_id" ]
  then
    gpg_key_id_from_base64_encoded_signature "$2"
  elif [ $1 == "-get_signed_data" ]
  then
    gpg_signed_data_from_base64_encoded_signature "$2"
  fi
elif [ $# -eq 3 ]
then
  if [ "$1" == "-sign" ]
  then
    # Ignore the second argument, which is the key_uid for now
    gpg_sign "$3"
    exit $SIGN_RESULT
  else
    print_usage
    exit 0
  fi
fi
