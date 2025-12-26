#!/bin/bash
# =============================================================================
# SSL Certificate Generation Script
# =============================================================================
# Generate self-signed certificates for development/testing
# For production, use Let's Encrypt or a trusted CA
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_DIR/certificates"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Default values
DOMAIN=${1:-"localhost"}
DAYS=${2:-365}
OPENIDDICT_PASSWORD=${3:-"openiddict"}

print_info "Generating certificates for domain: $DOMAIN"
print_warning "These are self-signed certificates for development/testing only!"
print_warning "For production, use Let's Encrypt or a trusted Certificate Authority."

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate SSL certificates for Nginx
print_info "Generating SSL certificates for Nginx..."

# Create CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days $DAYS -key ca.key -out ca.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=TrackHub CA"

# Create server key
openssl genrsa -out privkey.pem 2048

# Create CSR
openssl req -new -key privkey.pem -out server.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Create extensions file for SAN
cat > server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
DNS.3 = *.localhost
IP.1 = 127.0.0.1
EOF

# Sign the certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out fullchain.pem -days $DAYS -sha256 -extfile server.ext

print_success "SSL certificates generated: fullchain.pem, privkey.pem"

# Generate OpenIddict certificate
print_info "Generating OpenIddict certificate..."

openssl req -x509 -newkey rsa:4096 -keyout openiddict.key -out openiddict.crt \
    -days $DAYS -nodes \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=TrackHub OpenIddict"

openssl pkcs12 -export -out certificate.pfx -inkey openiddict.key -in openiddict.crt \
    -passout pass:$OPENIDDICT_PASSWORD

print_success "OpenIddict certificate generated: certificate.pfx"

# Cleanup temporary files
rm -f server.csr server.ext openiddict.key openiddict.crt ca.srl

print_success "Certificate generation complete!"
echo ""
print_info "Generated files in $CERT_DIR:"
ls -la "$CERT_DIR"
echo ""
print_info "SSL Certificate files:"
echo "  - fullchain.pem (Nginx SSL certificate)"
echo "  - privkey.pem (Nginx SSL private key)"
echo "  - ca.crt (CA certificate - for trusting self-signed certs)"
echo ""
print_info "OpenIddict Certificate:"
echo "  - certificate.pfx (password: $OPENIDDICT_PASSWORD)"
echo ""
print_warning "Remember to update CERTIFICATE_PASSWORD in .env if you changed the default password"
