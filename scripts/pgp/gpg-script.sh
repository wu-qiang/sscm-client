#!/bin/bash

#
# Configure HOMEDIR
#

declare GPG_HOMEDIR=

if [[ -n "$WERCKER_CACHE_DIR" && -d "$WERCKER_CACHE_DIR" ]] ; then
    GPG_HOMEDIR="$WERCKER_CACHE_DIR/gnupg"
else
    GPG_HOMEDIR="/tmp/gnupg"
fi

#
# Set up authority names
#

declare -a AUTHORITY_NAMES
declare -A AUTHORITY_PASSPHRASES

AUTHORITY_NAMES[0]="projects/build-infrastructure/attestationAuthorities/Build"
AUTHORITY_PASSPHRASES[${AUTHORITY_NAMES[0]}]="super-secret-0"

AUTHORITY_NAMES[1]="projects/build-infrastructure/attestationAuthorities/Test"
AUTHORITY_PASSPHRASES[${AUTHORITY_NAMES[1]}]="super-secret-1"

AUTHORITY_NAMES[2]="projects/build-infrastructure/attestationAuthorities/SecurityScan"
AUTHORITY_PASSPHRASES[${AUTHORITY_NAMES[2]}]="super-secret-2"

#
# GPG command and args we want to use
#

declare gpg_cmd="gpg --homedir $GPG_HOMEDIR --quiet"
declare gpg_batch_cmd="$gpg_cmd --batch --no-tty --pinentry-mode loopback"

#
# Functions
#

init_homedir() {
  # Make sure homedir is there, creating it if necessary
  if [ ! -d "$GPG_HOMEDIR" ]; then
    echo "Creating $GPG_HOMEDIR"
    mkdir -p $GPG_HOMEDIR || {
      echo "Can't create '$GPG_HOMEDIR'!"
      return 1
    }
  fi
  # For some reason, the mode change doesn't stick across pipelines
  chmod --changes 700 $GPG_HOMEDIR &>/dev/null || {
    echo "Can't change mode 700 for '$GPG_HOMEDIR'!"
    return 1
  }
  return 0
}

init_keyring() {
  local check_only="false"
  [[ "$1" == "--check-only" ]] && check_only="true"

  # For each authority, check whether we have a key. If an authority
  # key doesn't exist, generate it, or (if --check-only) return an error.

  local authority=
  for authority in $(gpg_get_authority_names)
  do
    if $gpg_cmd --list-keys --with-colons | grep ":${authority}:" > /dev/null; then
      if [[ "$check_only" != "true" ]] ; then
        echo "Key for '$authority' already exists."
      fi
    else
      if [[ "$check_only" == "true" ]] ; then
        echo "Key for '$authority' not found."
        return 1
      fi
      echo "Generating key for '$authority', this may take a while ..."
      echo "RSA" | $gpg_batch_cmd --passphrase "${AUTHORITY_PASSPHRASES[$authority]}" --quick-gen-key "$authority"
      if [ $? -eq 0 ] ; then
        echo "Key generated."
      else
        echo "Key generation failed!"
        return 1
      fi
    fi
  done

  if [[ "$check_only" != "true" ]] ; then
    $gpg_cmd --list-keys
  fi

  return 0
}

gpg_get_authority_names() {
  local index=
  for index in ${!AUTHORITY_NAMES[@]}
  do
    echo "${AUTHORITY_NAMES[$index]}"
  done
  return 0
}

gpg_get_authority_key() {
  # key's short id is the last 8 hex digits of its finger print
  # this is a bit fragile, but works for now
  local tmp=
  tmp=$($gpg_cmd --list-keys --with-colons "$1" 2>/dev/null | grep pub:u:2048:1:) || return 1
  [[ -n "$tmp" && "$tmp" != "" ]] || return 1
  echo "$tmp" | cut -c 22-29
  return 0
}

# Sign a string, base64 encode the result, and return it
gpg_sign() {
  local authority="$1"
  local data="$2"
  local tmp=
  tmp=$(gpg_get_authority_key "$authority") || return 1
  tmp=$(echo "$data" | $gpg_batch_cmd --passphrase "${AUTHORITY_PASSPHRASES[$authority]}" --local-user "$authority" --sign --armor) || return 1
  echo "$tmp" | base64 --wrap=0
  return 0
}

gpg_verify() {
  echo "$1" | base64 --decode | $gpg_cmd --verify 2> /dev/null
  return $?
}

gpg_getkeyid() {
  local tmp=
  tmp=$(echo "$1" | base64 --decode | $gpg_cmd --verify 2>&1)
  if [ $? -ne 0 ] ; then
    return 1
  fi
  echo "$tmp" | grep "using RSA key" | sed -e 's;.* ;;' -e 's;.*\([^ ]\{8\}\)$;\1;'
  return 0
}

gpg_getdata() {
  echo "$1" | base64 --decode | $gpg_cmd --decrypt 2> /dev/null
  return $?
}

gpg_test() {
  #
  # TODO: add test for gpg_getkeyid and gpg_getdata
  #

  local status=0
  local data="test one two three"
  local authority=
  local sig=

  # test that we can sign something using any of the authority keys and it'll verify
  for authority in $(gpg_get_authority_names)
  do
    echo "Test signing for '$authority' ..."
    if sig=$(gpg_sign "$authority" "$data") ; then
      echo "Test succeeded: signing succeeded for '$authority'"
    else
      echo "Test failed: signing failed for '$authority'"
      ((status++))
    fi
    echo "Test verification for '$authority' ..."
    if gpg_verify "$sig" ; then
      echo "Test succeeded: verification succeeded for '$authority'"
    else
      echo "Test failed: verification failed for '$authority'"
      ((status++))
    fi
  done

  # test that signing fails if don't have, e.g., valid keyid
  echo "Test that signing with bad authority name fails ..."
  sig=$(gpg_sign "this/attestation/authority/does/not/exist" "$data")
  if [ $? -eq 0 ]; then
    echo "Test failed: sign with bad authority name succeeded"
    ((status++))
  else
    echo "Test succeeded: sign with bad authority name failed"
  fi

  # test that verification fails for a bad signature
  local bad_sig="LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tClZlcnNpb246IEdudVBHIHYyCgpvd0VCUFFIQy9wQU5Bd0FJQWF2NVdVUk5DYUpCQWNzTllnQmFzVGxXWm05dlltRnlDb2tCSEFRQUFRZ0FCZ1VDCldyRTVWZ0FLQ1JDcitWbEVUUW1pUVZOSkNBQ0pxVlRLUnNpVjVIeGp3ZVFHdTNqMXN2NXBWOVZrMWdwMXU1clAKaTB2Tk95VGNsZnl5V1FkR2VGZnhtS0dHSjNFQ0UvM0VvNUhyZHJlbXBHU282d05aT251eFdpeWZ3NVorT25ONgp4eWxvUjNDTkY1NG12ZjJRRjRZTG9Sb2FJNFFFdk05bTBFNjVsZ3J2YW1JREt2R0ppTUZvcitGUnJNNHRJYVYrCmI5Q2xNY2NXcGlOQmJjeEhxVkpBWmlRS2pIMVV4cDVsdGZtNUwvcURZbGVQcjVzazBSdG1vcEcrMkNra0x0YkQKNytaQTlTMGNnR1g2cTNGL1VqZW9rZkFKaXBmL1dWdksreWNRR3R6eHc2VlRtbzZGNUJwQzlOdFd5T0dRQkRXdwo1WUhOQytNMktwenNOLzZHZlRkQ2Q4aFhhYUdtbGhJS0tldXZKS0gvNkc3SlNKZEwKPXdtTFkKLS0tLS1FTkQgUEdQIE1FU1NBR0UtLS0tLQo="

  echo "Test that bad signature (altered armored signature value) fails verification ..."
  if gpg_verify "$bad_sig" ; then
    echo "Test failed: bad signature was verified"
    ((status++))
  else
    echo "Test succeeded: bad signature not verified"
  fi

  # test that verification fails for a signature we don't have a key for
  local good_sig_no_key="LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tClZlcnNpb246IEdudVBHIHYyCgpvd0VCUFFIQy9wQU5Bd0FJQWF2NVdVUk5DYUpCQWNzTllnQmFzVGxXWm05dlltRnlDb2tCSEFRQUFRZ0FCZ1VDCldyRTVWZ0FLQ1JDcitWbEVUUW1pUVZOSkNBQ0pxVlRLUnNpVjVIeGp3ZVFHdTNqMXN2NXBWOVZrMWdwMXU1clAKaTB2Tk95VGNsZnl5V1FkR2VGZnhtS0dHSjNFQ0UvM0VvNUhyZHJlbXBHU282d05aT251eFdpeWZ3NVorT25ONgpBTE5qWTRDTkY1NG12ZjJRRjRZTG9Sb2FJNFFFdk05bTBFNjVsZ3J2YW1JREt2R0ppTUZvcitGUnJNNHRJYVYrCmI5Q2xNY2NXcGlOQmJjeEhxVkpBWmlRS2pIMVV4cDVsdGZtNUwvcURZbGVQcjVzazBSdG1vcEcrMkNra0x0YkQKNytaQTlTMGNnR1g2cTNGL1VqZW9rZkFKaXBmL1dWdksreWNRR3R6eHc2VlRtbzZGNUJwQzlOdFd5T0dRQkRXdwo1WUhOQytNMktwenNOLzZHZlRkQ2Q4aFhhYUdtbGhJS0tldXZKS0gvNkc3SlNKZEwKPXdtTFkKLS0tLS1FTkQgUEdQIE1FU1NBR0UtLS0tLQo="

  echo "Test that good signature fails verification if public key not available ..."
  if gpg_verify "$good_sig_no_key" ; then
    echo "Test failed: signature was verified without public key"
    ((status++))
  else
    echo "Test succeeded: signature not verified without public key"
  fi

  # return the accrued status
  if [ "$status" -eq "0" ] ; then
    echo "GPG TESTS SUCCEEDED"
  else
    echo "GPG TESTS FAILED ($status failure(s))"
  fi
  return $status
}

#
# Usage
#

print_usage() {
  printf "Command usage for $0:\n"
  printf "==================================\n"
  printf "$0 --init-keyring\n"
  printf "Explicitly initialize the keyring.\n\n"

  printf "$0 --get-authority-names\n"
  printf "Get the names of the known attestation authorities.\n\n"

  printf "$0 --get-authority-keyid <authority_name>\n"
  printf "Get the public key id for the specified authority.\n\n"

  printf "$0 --sign <authority_name> \"<string_to_be_signed>\"\n"
  printf "Sign a string using the key of the named authority.\n\n"

  printf "$0 --verify \"<base64_encoded_signature>\"\n"
  printf "Verify a signature. Returns 0 or 1 to indicate signature validity.\n\n"

  printf "$0 --get-signature-keyid \"<base64_encoded_signature>\"\n"
  printf "Get the short ID(last 8 Hex digits of the key's finger print) of the key that was used\n"
  printf "to sign the provided signature. Returns 0 or 1 to indicate signature validity.\n\n"

  printf "$0 --get-signature-data \"<base64_encoded_signature>\"\n"
  printf "Get the signed data from the encoded signature. Returns 0 or 1 to indicate signature validity.\n\n"
}

#
# Main script
#

init_homedir || exit 1
if [ "$1" != "--init-keyring" ] ; then
  init_keyring --check-only || exit 1
fi

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
--test)                 gpg_test || exit 1
                        ;;
*)                      print_usage ; exit 1
                        ;;
esac

exit 0

