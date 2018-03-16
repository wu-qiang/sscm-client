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

init_keyring() {

  # Check environment
  if [ -z "$GPG_HOMEDIR" -o ! -d "$GPG_HOMEDIR" ] ; then
    echo "GPG_HOMEDIR not set or not accessible!"
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

  # Make sure homedir is there
  if [ ! -d "$GPG_HOMEDIR" ]; then
    echo "Creating $GPG_HOMEDIR"
    mkdir -p $GPG_HOMEDIR || return 1
    chmod 700 $GPG_HOMEDIR || return 1
  fi

  # Check if we have key for $GPG_AUTHORITY_NAME and generate if needed

  if $gpg_cmd --list-keys --with-colons | grep ":${GPG_AUTHORITY_NAME}:" > /dev/null; then
    echo "Key for '$GPG_AUTHORITY_NAME' exists"
  else
    echo "Generating key for '$GPG_AUTHORITY_NAME', this may take a while ..."
    echo "RSA" | $gpg_cmd --no-tty --yes --batch --passphrase foobar --quick-gen-key "projects/foobar/mumble/key2"
    if [ $? -eq 0 ] ; then
      echo "Key generated."
    else
      echo "Key generation failed!"
      return 1
    fi
  fi

  return 0
}

gpg_get_authority_names() {
  echo "$GPG_AUTHORITY_NAME"
  return 0
}

gpg_get_authority_key() {
  # key's short id is the last 8 hex digits of its finger print
  # this is a bit fragile, but works for now
  $gpg_cmd --list-keys --with-colons $1 | grep pub:u:2048:1: | cut -c 22-29
  return $?
}

print_usage() {
  echo "USAGE: $0 {init|get_authority_names|get_authority_key <authority>}"
}

case "$1" in
init)                   exit init_keyring ;;
get_authority_names)    exit gpg_get_authority_names ;;
get_authority_key)      exit gpg_get_authority_key "$1" ;;
*)                      print_usage ; exit 1 ;;
esac

