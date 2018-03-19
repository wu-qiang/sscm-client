# SSCM Client Support Code

This repository contains code for the plugins needed to generate and upload notes, occurrences, and attestations related to building an application, and authorization for deployment based on those attestations.

It contains the following:

* Maven plugins for build, test, and security-scan goals
* Gradle plugins for build, test, and security-scan goals
* Scripts to support signing metadata objects and verifying signatures
* Scripts to support making deployment decisions based on attestations

## PGP Script Usage

The gpg-script.sh script provides for signing and verification of data provided as an argument to the script:
```
gpg-script.sh --sign "<authority-name>" "<data-to-be-signed>"

gpg-script.sh --verify "<signature-string>"
gpg-script.sh --get-signature-keyid "<signature-string>"
gpg-script.sh --get-signature-data "<signature-string>"
```
The first form signs the provided data using the key identified by _authority-name_, outputs the resulting signature as a base64-encoded string. The _authority-name_ identifies an attestation authority using it's full name.

The last three forms verify a base64-encoded _signature-string_, provided as a parameter. The *verify* operation simply returns 0 or 1 to indicate success or failure. The *getkey* opereration returns 0 or 1 to indicate whether the signature is valid, and outputs the short-form keyid of the public key that verified the signature. The *getdata* operation returns 0 or 1 to indicate whether the signature is valid, and outputs the data that was signed.

The signatures produced/verified are attached, ascii-armored PGP signatures.

The script also provides functions to initialize the local keyring, to get the names of known attestation authorities, and to get the key id for an attestation authority:
```
gpg-script.sh --init-keyring
gpg-script.sh --get-authority-names
gpg-script.sh --get-authority-keyid <authority-name>
```

## SBAS Script Usage

If want to execute "Attestation Authority" check, we must execute the script `authorities-generator.sh` before `sbas-check.sh`.

These 2 scripts depend on below environment variables:

* GRAFEAS_SERVER_ADDRESS: the host of the Grafeas server.
* GRAFEAS_SERVER_PORT: the port of the Grafeas server.
* GPG_SCRIPT: the script that execute pgp sign and verify.
* ATTESTATION_AUTHORITY_FILE: the location to store attestation authority data.

To generate the attestation authority file, run:

```bash
authorities-generator.sh
```

This script will call "GPG_SCRIPT" to get attestation name and key id. The result is wrote to the file "ATTESTATION_AUTHORITY_FILE".

To check if a resource can be deployed, run script:

```bash
sbas-check.sh <project name> <resource url> <cluster name>

sbas-check.sh build https://host/demo/build@sha256:aba48d60ba4410ec921f9d2e8169236c57660d121f9430dc9758d754eec8f887 experimental
```

