#!/bin/bash

#
# These environment variables come from Wercker environment.
# Must be set before running script.
#
# GPG_HOMEDIR
# GPG_ATTESTATION_AUTHORITY
# GPG_PASSPHRASE
#

declare gpg_cmd="gpg --homedir $GPG_HOMEDIR --quiet"
declare gpg_batch_cmd="$gpg_cmd --batch --no-tty --pinentry-mode loopback"

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
    echo "RSA" | $gpg_batch_cmd --passphrase "$GPG_PASSPHRASE" --quick-gen-key "$GPG_AUTHORITY_NAME"
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

# Sign a string, base64 encode the result, and return it
gpg_sign() {
  local tmp=
  tmp=$(echo "$2" | $gpg_batch_cmd --passphrase $GPG_PASSPHRASE --user "$GPG_AUTHORITY_NAME" --sign --armor)
  if [ $? -ne 0 ] ; then
    return 1
  fi
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
  # TODO: add test for get_keyid and get_data
  #

  local status=0
  local data="test one two three"

  # test that we can sign something using any of the authority keys and it'll verify
  echo "Test signing/verification for all authority names ..."
  for i in $(gpg_get_authority_names)
  do
    local sig=
    sig=$(gpg_sign "$i" "$data") || {
      echo "Test failed: signing failed for authority '$i'"
    }
    gpg_verify "$sig" || {
      echo "Test failed: verification failed for authority '$i'"
      status=1
  done
  if [ "$status" -eq "0" ] ; then
    echo "Test succeeded: sigining and verification for all authority names"
  fi

  # test that signing fails if don't have, e.g., valid keyid
  echo "Test that signing with bad authority name fails ..."
  if gpg_sign "this/attestation/authority/does/not/exist" "$data" ; then
    echo "Test failed: sign with bad authority name succeeded"
    status=1
  else
    else "Test succeeded: sign with bad authority name failed"
  fi

  # test that verification fails for a bad signature
  local bad_sig="LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tClZlcnNpb246IEdudVBHIHYyCgpvd0VCUFFIQy9wQU5Bd0FJQWF2NVdVUk5DYUpCQWNzTllnQmFzVGxXWm05dlltRnlDb2tCSEFRQUFRZ0FCZ1VDCldyRTVWZ0FLQ1JDcitWbEVUUW1pUVZOSkNBQ0pxVlRLUnNpVjVIeGp3ZVFHdTNqMXN2NXBWOVZrMWdwMXU1clAKaTB2Tk95VGNsZnl5V1FkR2VGZnhtS0dHSjNFQ0UvM0VvNUhyZHJlbXBHU282d05aT251eFdpeWZ3NVorT25ONgp4eWxvUjNDTkY1NG12ZjJRRjRZTG9Sb2FJNFFFdk05bTBFNjVsZ3J2YW1JREt2R0ppTUZvcitGUnJNNHRJYVYrCmI5Q2xNY2NXcGlOQmJjeEhxVkpBWmlRS2pIMVV4cDVsdGZtNUwvcURZbGVQcjVzazBSdG1vcEcrMkNra0x0YkQKNytaQTlTMGNnR1g2cTNGL1VqZW9rZkFKaXBmL1dWdksreWNRR3R6eHc2VlRtbzZGNUJwQzlOdFd5T0dRQkRXdwo1WUhOQytNMktwenNOLzZHZlRkQ2Q4aFhhYUdtbGhJS0tldXZKS0gvNkc3SlNKZEwKPXdtTFkKLS0tLS1FTkQgUEdQIE1FU1NBR0UtLS0tLQo="

  echo "Test that bad signature (altered armored signature value) fails verification ..."
  if gpg_verify "$bad_sig" ; then
    echo "Test failed: bad signature was verified"
    status=1
  else
    echo "Test succeeded: bad signature not verified"
  fi

  # test that verification fails for a signature we don't have a key for
  local good_sig_no_key="LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tClZlcnNpb246IEdudVBHIHYyCgpvd0VCUFFIQy9wQU5Bd0FJQWF2NVdVUk5DYUpCQWNzTllnQmFzVGxXWm05dlltRnlDb2tCSEFRQUFRZ0FCZ1VDCldyRTVWZ0FLQ1JDcitWbEVUUW1pUVZOSkNBQ0pxVlRLUnNpVjVIeGp3ZVFHdTNqMXN2NXBWOVZrMWdwMXU1clAKaTB2Tk95VGNsZnl5V1FkR2VGZnhtS0dHSjNFQ0UvM0VvNUhyZHJlbXBHU282d05aT251eFdpeWZ3NVorT25ONgpBTE5qWTRDTkY1NG12ZjJRRjRZTG9Sb2FJNFFFdk05bTBFNjVsZ3J2YW1JREt2R0ppTUZvcitGUnJNNHRJYVYrCmI5Q2xNY2NXcGlOQmJjeEhxVkpBWmlRS2pIMVV4cDVsdGZtNUwvcURZbGVQcjVzazBSdG1vcEcrMkNra0x0YkQKNytaQTlTMGNnR1g2cTNGL1VqZW9rZkFKaXBmL1dWdksreWNRR3R6eHc2VlRtbzZGNUJwQzlOdFd5T0dRQkRXdwo1WUhOQytNMktwenNOLzZHZlRkQ2Q4aFhhYUdtbGhJS0tldXZKS0gvNkc3SlNKZEwKPXdtTFkKLS0tLS1FTkQgUEdQIE1FU1NBR0UtLS0tLQo="

  echo "Test that good signature fails verification if public key not available ..."
  if gpg_verify "$good_sig_no_key" ; then
    echo "Test failed: signature was verified without public key"
    status=1
  else
    echo "Test succeeded: signature not verified without public key"
  fi

  # return the accrued status
  return $status
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
--test)                 gpg_test || exit 1
                        ;;
*)                      print_usage ; exit 1
                        ;;
esac

exit 0

