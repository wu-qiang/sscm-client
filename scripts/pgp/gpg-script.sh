#!/bin/bash

#
# These environment variables come from Wercker environment.
# Must be set before running script.
#
# GPG_HOMEDIR
# GPG_ATTESTATION_AUTHORITY
# GPG_PASSPHRASE
#

typeset gpg_cmd="gpg --homedir $GPG_HOMEDIR"

# Sign a string, base64 encode the result and return it
gpg_sign() {
  local str="$2"
  echo "$str" | gpg -q --no-verbose --no-tty --batch --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --armor --sign --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2>/dev/null | base64 -w 0
  if [ $? -eq 0 ]; then
    SIGN_RESULT=0
    # output the signature
    #echo "BASE64_ENCODED_SIGNATURE:::"`base64 -w 0 $out_file`":::BASE64_ENCODED_SIGNATURE"
    #rm $out_file
  fi
}

gpg_verify() {
  local encodedSig="$1"
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --verify
  if [ $? -eq 0 ]; then
    #if [ "$result" == "$original_text" ]; then
      #printf "Signature is both valid and matched\n"
      VERIFY_RESULT=$?
    #else
    #  printf "Signature does not match\n"
    #fi
  fi
}

gpg_getkeyid() {
  local encodedSig="$1"
  local key_id=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME -q --no-tty --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2>&1)
echo "key id:[$key_id]"
  # key's short id is the last 8 hex digits of its finger print
}

gpg_getdata() {
  local encodedSig="$1"
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2> /dev/null
  # key's short id is the last 8 hex digits of its finger print
  #local in_file=$(mktemp)
  #local out_file=$(mktemp)
  #echo "temp files: $in_file & $out_file"
  #echo "$encodedSig" | base64 --decode > $in_file
  #echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE
  #gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --batch --output $out_file $in_file
  #gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --batch -o $out_file --pinentry-mode loopback --passphrase $GPG_PASSPHRASE
}

print_usage() {
  printf "Command usage for $0:\n"
  printf "==================================\n"
  printf "$0 sign <authority_name> \"<string_to_be_signed>\"\n"
  printf "Sign a string using the key of the named authority.\n\n"

  printf "$0 verify \"<base64_encoded_signature>\"\n"
  printf "Verify a signature.n\n"

  printf "$0 getkeyid \"<base64_encoded_signature>\"\n"
  printf "Get the short ID(last 8 Hex digits of the key's finger print) of the key that was used to sign the provided signature.\n\n"

  printf "$0 -getdata \"<base64_encoded_signature>\"\n"
  printf "Get the original data from the encoded signature\n\n"
}

# This will fail if env not set correctly
gpg-mgmt.sh init || exit 1

case "$1" in
sign)       exit gpg_sign "$2" "$3" ;;
verify)     exit gpg_verify "$2" ;;
getkeyid)   exit gpg_getkeyid "$2" ;;
getdata)    exit gpg_getdata "$2" ;;
*)          print_usage ; exit 1 ;;
esac

