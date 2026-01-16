#!/bin/sh
# =============================================================================
# Initialize Kerberos Principals and Keytabs for Hive 3.x
# =============================================================================
# This script runs inside the KDC container for the Hive 3.x test environment.
# It creates principals for the Hive 3.x metastore service.
#
# Principals Created:
# - hive/hive3-metastore@TEST.LOCAL (HMS service - short hostname)
# - hive/hive3-metastore.test.local@TEST.LOCAL (HMS service - FQDN)
# - testuser@TEST.LOCAL (Test user for client connections)
# =============================================================================

set -e

REALM="TEST.LOCAL"
KEYTAB_DIR="/keytabs"

echo "=============================================="
echo "Initializing Kerberos Principals (Hive 3.x)"
echo "=============================================="

# Clean up any existing keytabs to ensure fresh keys
rm -f ${KEYTAB_DIR}/*.keytab 2>/dev/null || true

echo ""
echo "1. Creating service principals..."

# Hive 3.x HMS principals (both short and FQDN for compatibility)
kadmin.local -q "addprinc -randkey hive/hive3-metastore@${REALM}" 2>/dev/null || true
kadmin.local -q "addprinc -randkey hive/hive3-metastore.test.local@${REALM}" 2>/dev/null || true

# Test user principal for client connections
kadmin.local -q "addprinc -randkey testuser@${REALM}" 2>/dev/null || true

# HTTP principals for web UIs
kadmin.local -q "addprinc -randkey HTTP/hive3-metastore@${REALM}" 2>/dev/null || true

echo "   ✓ Principals created"

echo ""
echo "2. Exporting keytabs..."

# Hive 3.x service keytab
kadmin.local -q "ktadd -k ${KEYTAB_DIR}/hive.keytab hive/hive3-metastore@${REALM}"
kadmin.local -q "ktadd -k ${KEYTAB_DIR}/hive.keytab hive/hive3-metastore.test.local@${REALM}"

# HTTP keytab
kadmin.local -q "ktadd -k ${KEYTAB_DIR}/http.keytab HTTP/hive3-metastore@${REALM}"

# Test user keytab
kadmin.local -q "ktadd -k ${KEYTAB_DIR}/testuser.keytab testuser@${REALM}"

# Set permissions (readable by all containers sharing the volume)
chmod 644 ${KEYTAB_DIR}/*.keytab

echo "   ✓ Keytabs exported"

echo ""
echo "3. Verification..."
echo ""
echo "Keytab files:"
ls -la ${KEYTAB_DIR}/

echo ""
echo "Hive keytab contents:"
klist -kt ${KEYTAB_DIR}/hive.keytab

echo ""
echo "Testuser keytab contents:"
klist -kt ${KEYTAB_DIR}/testuser.keytab

echo ""
echo "=============================================="
echo "✅ Kerberos initialization complete (Hive 3.x)!"
echo "=============================================="

