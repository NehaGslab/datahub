#!/bin/bash
# Custom entrypoint for Hive 3.x Metastore with Kerberos
# This script ensures proper Kerberos configuration before starting HMS

set -e

echo "=============================================="
echo "Hive 3.x Metastore with Kerberos"
echo "=============================================="

# Database connection settings
DB_URL="jdbc:postgresql://hive3-metastore-postgresql:5432/metastore"
DB_DRIVER="org.postgresql.Driver"
DB_USER="hive"
DB_PASS="hive"

# Wait for dependencies
echo "Waiting for PostgreSQL..."
until nc -z hive3-metastore-postgresql 5432; do
    sleep 2
done
echo "✓ PostgreSQL is ready"

# Give PostgreSQL a moment to be fully ready
sleep 5

echo "Waiting for keytab..."
until [ -f /keytabs/hive.keytab ]; do
    sleep 2
done
echo "✓ Keytab is ready"

# Verify keytab is valid
echo "Verifying keytab..."
klist -kt /keytabs/hive.keytab
echo "✓ Keytab verified"

# Login with the service principal keytab - this sets up Kerberos for the process
echo "Authenticating as Hive service..."
kinit -kt /keytabs/hive.keytab hive/hive3-metastore.test.local@TEST.LOCAL
klist
echo "✓ Kerberos authentication complete"

# Export the principal for Hadoop UGI
export HADOOP_USER_NAME="hive"
export KRB5CCNAME="/tmp/krb5cc_hive"

# Initialize the metastore schema
echo "Initializing metastore schema..."
/opt/hive/bin/schematool -dbType postgres \
    -url "$DB_URL" \
    -driver "$DB_DRIVER" \
    -userName "$DB_USER" \
    -passWord "$DB_PASS" \
    -initSchema \
    -verbose 2>&1 || {
    echo "Schema init failed or already exists, trying upgrade..."
    /opt/hive/bin/schematool -dbType postgres \
        -url "$DB_URL" \
        -driver "$DB_DRIVER" \
        -userName "$DB_USER" \
        -passWord "$DB_PASS" \
        -upgradeSchema \
        -verbose 2>&1 || echo "Schema already up to date"
}
echo "✓ Schema initialization complete"

# Start the metastore with explicit Kerberos configuration
echo "Starting Hive Metastore..."
exec /opt/hive/bin/hive --service metastore \
    --hiveconf hive.metastore.sasl.enabled=true \
    --hiveconf hive.metastore.kerberos.keytab.file=/keytabs/hive.keytab \
    --hiveconf "hive.metastore.kerberos.principal=hive/hive3-metastore.test.local@TEST.LOCAL" \
    --hiveconf hive.metastore.thrift.sasl.qop=auth-conf \
    --hiveconf hive.metastore.schema.verification=false \
    --hiveconf hive.metastore.schema.verification.record.version=false \
    --hiveconf datanucleus.autoCreateSchema=true \
    --hiveconf datanucleus.schema.autoCreateTables=true \
    --hiveconf javax.jdo.option.ConnectionURL="$DB_URL" \
    --hiveconf javax.jdo.option.ConnectionDriverName="$DB_DRIVER" \
    --hiveconf javax.jdo.option.ConnectionUserName="$DB_USER" \
    --hiveconf javax.jdo.option.ConnectionPassword="$DB_PASS"

