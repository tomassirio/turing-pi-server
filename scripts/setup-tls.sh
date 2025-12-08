#!/bin/bash

# Usage: ./scripts/setup-tls.sh
# This script creates a self-signed wildcard certificate for *.localhome.com
# and outputs the content to be added to secrets.dec.yaml

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

DOMAIN="localhome.com"
CERT_DIR="$(dirname "$0")/../certs"

echo -e "${BLUE}
+==================================================+
|                                                  |
|      🔐  TLS Certificate Setup  🔐               |
|                                                  |
+==================================================+
${NC}"

# Create certs directory if it doesn't exist
mkdir -p "$CERT_DIR"

echo -e "${BLUE}📜  Generating self-signed wildcard certificate for ${PURPLE}*.${DOMAIN}${NC}"

# Generate private key
openssl genrsa -out "$CERT_DIR/tls.key" 2048 2>/dev/null

# Generate certificate signing request config
cat > "$CERT_DIR/csr.conf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = NL
ST = North Holland
L = Amsterdam
O = Turing Pi Home Lab
OU = Home Lab
CN = *.${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EOF

# Generate certificate signing request
openssl req -new -key "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.csr" -config "$CERT_DIR/csr.conf" 2>/dev/null

# Generate self-signed certificate (valid for 365 days)
cat > "$CERT_DIR/cert.conf" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EOF

openssl x509 -req -in "$CERT_DIR/tls.csr" -signkey "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.crt" \
  -days 365 -sha256 -extfile "$CERT_DIR/cert.conf" 2>/dev/null

echo -e "${GREEN}✅  Certificate generated successfully!${NC}"
echo ""

# Read the certificate and key content
CRT_CONTENT=$(cat "$CERT_DIR/tls.crt")
KEY_CONTENT=$(cat "$CERT_DIR/tls.key")

echo -e "${BLUE}
+==================================================+
|                                                  |
|       📝  Add to secrets.dec.yaml  📝           |
|                                                  |
+==================================================+
${NC}"

echo -e "${YELLOW}Add the following to your ${PURPLE}config/secrets/secrets.dec.yaml${YELLOW} file:${NC}"
echo ""
echo -e "${GREEN}tls:
  localhome:
    crt: |"
echo "$CRT_CONTENT" | sed 's/^/      /'
echo "    key: |"
echo "$KEY_CONTENT" | sed 's/^/      /'
echo -e "${NC}"

echo -e "${BLUE}
+==================================================+
|                                                  |
|          🎉  TLS Setup Complete  🎉              |
|                                                  |
+==================================================+
${NC}"

echo -e "${YELLOW}📝  Next steps:${NC}"
echo -e "  1. Copy the YAML above and add it to ${PURPLE}config/secrets/secrets.dec.yaml${NC}"
echo -e "  2. Encrypt the secrets file: ${PURPLE}sops -e config/secrets/secrets.dec.yaml > config/secrets/secrets.yaml${NC}"
echo -e "  3. Deploy cluster secrets: ${PURPLE}helm secrets upgrade -i cluster-secrets ./config/secrets -f ./config/secrets/secrets.yaml${NC}"
echo -e "  4. Deploy your services: ${PURPLE}./deploy-services.sh${NC}"
echo -e ""
echo -e "${YELLOW}🍎  To trust the certificate on macOS (removes browser warnings):${NC}"
echo -e "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${CERT_DIR}/tls.crt"
echo ""

# Also save the YAML snippet to a file for easy copy-paste
cat > "$CERT_DIR/tls-secrets-snippet.yaml" << EOF
tls:
  localhome:
    crt: |
$(echo "$CRT_CONTENT" | sed 's/^/      /')
    key: |
$(echo "$KEY_CONTENT" | sed 's/^/      /')
EOF

echo -e "${GREEN}💾  YAML snippet also saved to: ${PURPLE}${CERT_DIR}/tls-secrets-snippet.yaml${NC}"

