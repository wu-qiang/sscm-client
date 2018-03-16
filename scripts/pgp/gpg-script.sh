#!/bin/bash

# These come from Wercker environment
# GPG_HOMEDIR
# GPG_ATTESTATION_AUTHORITY
# GPG_PASSPHRASE

SIGN_RESULT=1
VERIFY_RESULT=1

# Sign a string, base64 encode the result and return it
gpg_sign() {
  local str="$1"
  #echo "signing $str"
  #local out_file=$(mktemp)
  #if [ -e $out_file ]
  #then
  #  rm $out_file
  #fi
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

gpg_verify_and_match() {
  local encodedSig="$1"
  #local original_text="$2"
  #local result=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2> /dev/null)
  echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2> /dev/null
  #gpg --homedir $GPG_HOMEDIR -k --keyid-format short $GPG_AUTHORITY_NAME  2> /dev/null
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
  gpg --homedir $GPG_HOMEDIR -k --no-tty --with-colons $GPG_AUTHORITY_NAME  2> /dev/null | grep pub:u:2048:1:|cut -c 22-29
}

gpg_key_id_from_base64_encoded_signature() {
  local encodedSig="$1"
  local key_id=$(echo "$encodedSig" | base64 --decode | gpg --homedir $GPG_HOMEDIR -u $GPG_AUTHORITY_NAME -q --no-tty --decrypt --pinentry-mode loopback --passphrase $GPG_PASSPHRASE 2>&1)
echo "key id:[$key_id]"
  # key's short id is the last 8 hex digits of its finger print
}

gpg_signed_data_from_base64_encoded_signature() {
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
  printf "$0 -sign <key_uid> \"<string_to_be_signed>\"\n"
  printf "Sign a string using the key stored under the key_uid(e.g. sscm_attestation_auth@oracle.com).\n\n"

  printf "$0 -verify \"<base64_encoded_signature>\"\n"
  printf "Base64 decode the signature and verify.\n\n"

  printf "$0 -get_key_id \"<base64_encoded_signature>\"\n"
  printf "Get the short ID(last 8 Hex digits of the key's finger print) of the key that was used to sign the provided signature.\n\n"

  printf "$0 -get_signed_data \"<base64_encoded_signature>\"\n"
  printf "Get the original data from the encoded signature\n\n"
}

gpg-mgmt.sh init

case "$1" in
sign)       gpg_sign "$3"  # Ignore the second argument, which is the key_uid for now
            exit $SIGN_RESULT
            ;;
verify)     gpg_verify "$2"
            exit $VERIFY_RESULT
            ;;
getkeyid)   gpg_key_id_from_base64_encoded_signature "$2"
            # this needs an exit value that indicates if signature valid
            ;;
getdata)    gpg_signed_data_from_base64_encoded_signature "$2"
            # this needs an exit value that indicates if signature valid
            ;;
*)          print_usage
            exit 1
            ;;
esac
