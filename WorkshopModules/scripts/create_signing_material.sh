#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /private/path/to/workshop-signing-directory" >&2
    exit 2
fi

OUTPUT_DIR="$1"
mkdir -p "$OUTPUT_DIR"
umask 077
PRIVATE_KEY="$OUTPUT_DIR/workshop-private.pem"
CERTIFICATE_PEM="$OUTPUT_DIR/workshop-public.pem"
CERTIFICATE_DER="$OUTPUT_DIR/workshop-public.der"

if [ -e "$PRIVATE_KEY" ]; then
    echo "Refusing to replace existing private key: $PRIVATE_KEY" >&2
    exit 1
fi

openssl genrsa -out "$PRIVATE_KEY" 3072
openssl req -new -x509 -sha256 -key "$PRIVATE_KEY" -out "$CERTIFICATE_PEM" \
    -days 3650 -subj "/CN=Telegraphica Workshop Module Signing/O=Telegraphica Workshop"
openssl x509 -in "$CERTIFICATE_PEM" -outform der -out "$CERTIFICATE_DER"
chmod 600 "$PRIVATE_KEY"

echo "Private key: $PRIVATE_KEY"
echo "Public certificate: $CERTIFICATE_DER"
echo "Keep the private key outside the repository and back it up securely."
