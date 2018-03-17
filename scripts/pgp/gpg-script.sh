#!/bin/bash

#
# These environment variables come from Wercker environment.
# Must be set before running script.
#
# GPG_HOMEDIR
# GPG_ATTESTATION_AUTHORITY
# GPG_PASSPHRASE
#

typeset gpg_cmd="gpg --homedir $GPG_HOMEDIR --quiet"

check_environment() {
  # Check the environment
  if [ -z "$GPG_HOMEDIR" ] ; then
    echo "GPG_HOMEDIR not set!"
    return 1
  fi
  if [ -z "$GPG_AUTHORITY_NAME" ] ; then
    echo "GPG_AUTHORITY_NAME not set!"
    return 1
  fi
  if [ -z "$GPG_PASSPHRASE" ] ; then
    echo "GPG_PASSPHRASE not set!"
    return 1
  fi
  return 0
}

check_homedir() {
  # Make sure homedir is there
  if [ ! -d "$GPG_HOMEDIR" ]; then
    echo "Creating $GPG_HOMEDIR"
    mkdir -p $GPG_HOMEDIR || {
      echo "Can't create '$GPG_HOMEDIR'!"
      return 1
    }
  fi
  # For some reason, the mode change doesn't stick across pipelines
  chmod --changes 700 $GPG_HOMEDIR || {
    echo "Can't change mode 700 for '$GPG_HOMEDIR'!"
    return 1
  }
  return 0
}

init_keyring() {
  # Check whether we have a key for $GPG_AUTHORITY_NAME, and generate if needed
  if $gpg_cmd --list-keys --with-colons | grep ":${GPG_AUTHORITY_NAME}:" > /dev/null; then
    echo "Key for '$GPG_AUTHORITY_NAME' exists."
  else
    echo "Generating key for '$GPG_AUTHORITY_NAME', this may take a while ..."
    echo "RSA" | $gpg_cmd --batch --no-tty --passphrase "$GPG_PASSPHRASE" --quick-gen-key "$GPG_AUTHORITY_NAME"
    if [ $? -eq 0 ] ; then
      echo "Key generated."
    else
      echo "Key generation failed!"
      return 1
    fi
  fi

  $gpg_cmd --list-keys

  return 0
}

gpg_get_authority_names() {
  echo "$GPG_AUTHORITY_NAME"
  return 0
}

gpg_get_authority_key() {
  # key's short id is the last 8 hex digits of its finger print
  # this is a bit fragile, but works for now
  $gpg_cmd --list-keys --with-colons "$1" | grep pub:u:2048:1: | cut -c 22-29
  return $?
}

# Sign a string, base64 encode the result and return it
gpg_sign() {
  echo "$2" | $gpg_cmd --batch --no-tty --pinentry-mode loopback --passphrase $GPG_PASSPHRASE --user "$GPG_AUTHORITY_NAME" --sign --armor | base64 -w 0
# --pinentry-mode loopback 2>/dev/null | base64 -w 0
return 1
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
  printf "$0 --init-keyring\n"
  printf "Initialize the keyring with authority keys.\n\n"

  printf "$0 --get-authority-names\n"
  printf "Get the names of the configured attestation authorities.\n\n"

  printf "$0 --get-authority-keyid <authority_name>\n"
  printf "Get the keyid for the specified authority name.\n\n"

  printf "$0 --sign <authority_name> \"<string_to_be_signed>\"\n"
  printf "Sign a string using the key of the named authority.\n\n"

  printf "$0 --verify \"<base64_encoded_signature>\"\n"
  printf "Verify a signature. Returns 0 or 1 to indicate signature validity.\n\n"

  printf "$0 --get-signature-keyid \"<base64_encoded_signature>\"\n"
  printf "Get the short ID(last 8 Hex digits of the key's finger print) of the key that was used to sign the provided signature. Returns 0 or 1 to indicate signature validity.\n\n"

  printf "$0 --get-signature-data \"<base64_encoded_signature>\"\n"
  printf "Get the signed data from the encoded signature. Returns 0 or 1 to indicate signature validity.\n\n"
}

#
# Make sure the environment looks right and the homedir exists before
# attempting to do anything. If homedir is there, keys should be, too.
#
# TODO: refactor so we can check for the existence of keys without
# producing a lot of spurious output about the existence of keys.
#

check_environment || exit 1
check_homedir || exit 1

case "$1" in
--init-keyring)         init_keyring || exit 1
                        ;;
--get-authority-names)  gpg_get_authority_names || exit 1
                        ;;
--get-authority-keyid)  gpg_get_authority_key "$2" || exit 1
                        ;;
--sign)                 gpg_sign "$2" "$3" || exit 1
                        ;;
--verify)               gpg_verify "$2" || exit 1
                        ;;
--get-signature-keyid)  gpg_getkeyid "$2" || exit 1
                        ;;
--get-signature-data)   gpg_getdata "$2" || exit 1
                        ;;
*)                      print_usage ; exit 1
                        ;;
esac

exit 0

