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
