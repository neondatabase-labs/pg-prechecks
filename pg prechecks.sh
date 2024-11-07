#!/bin/bash

# PostgreSQL Pre-Check Script
# This script collects information about a PostgreSQL instance and generates a summary report.

set -e

# Default values
PGHOST="your-rds-endpoint.region.rds.amazonaws.com"
PGPORT="5432"
PGUSER="your_rds_master_username"
PGDATABASE="postgres"
OUTPUT_DIR="pg_precheck_$(date +%Y%m%d_%H%M%S)"

# Function to execute PostgreSQL queries
run_query() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -c "$1"
}

# Function to collect PostgreSQL information
collect_pg_info() {
    mkdir -p "$OUTPUT_DIR"

    # Check for logical replication support
    run_query "SELECT CASE WHEN setting = 'logical' THEN 'Supported' ELSE 'Not supported' END AS logical_replication_support FROM pg_settings WHERE name = 'wal_level';" > "$OUTPUT_DIR/logical_replication.txt"

    # Check for number of replicas
    run_query "SELECT count(*) FROM pg_stat_replication;" > "$OUTPUT_DIR/replica_count.txt"

    # Version information
    run_query "SELECT version();" > "$OUTPUT_DIR/version.txt"

    # List of databases
    run_query "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" > "$OUTPUT_DIR/databases.txt"

    # Database sizes
    run_query "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;" > "$OUTPUT_DIR/database_sizes.txt"

    # Table and index sizes (top 20)
    run_query "SELECT schemaname || '.' || tablename AS table_name, 
               pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
               pg_size_pretty(pg_table_size(schemaname || '.' || tablename)) AS table_size,
               pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size
               FROM pg_tables 
               ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC 
               LIMIT 20;" > "$OUTPUT_DIR/table_index_sizes.txt"

    # Settings
    run_query "SELECT name, setting, unit, context FROM pg_settings ORDER BY name;" > "$OUTPUT_DIR/settings.txt"

    # Extensions
    run_query "SELECT * FROM pg_extension;" > "$OUTPUT_DIR/extensions.txt"

    # Activity
    run_query "SELECT * FROM pg_stat_activity;" > "$OUTPUT_DIR/activity.txt"

    # Indexes
    run_query "SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes ORDER BY schemaname, tablename;" > "$OUTPUT_DIR/indexes.txt"

    # Roles
    run_query "SELECT * FROM pg_roles;" > "$OUTPUT_DIR/roles.txt"

    # Long-Running Queries
    echo "----------------------------------" > "$OUTPUT_DIR/long_running_queries.txt"
    echo " Long-Running Queries" >> "$OUTPUT_DIR/long_running_queries.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/long_running_queries.txt"
    run_query "SELECT pid, 
               now() - pg_stat_activity.query_start AS duration, 
               query 
               FROM pg_stat_activity 
               WHERE state != 'idle' 
               AND now() - pg_stat_activity.query_start > interval '5 minutes' 
               ORDER BY duration DESC;" >> "$OUTPUT_DIR/long_running_queries.txt"

    # Locks Information
    echo "----------------------------------" > "$OUTPUT_DIR/locks_information.txt"
    echo " Locks Information" >> "$OUTPUT_DIR/locks_information.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/locks_information.txt"
    run_query "SELECT l.pid, 
               locktype, 
               mode, 
               granted, 
               relation::regclass AS table_name,
               a.query
               FROM pg_locks l
               JOIN pg_stat_activity a ON l.pid = a.pid
               WHERE relation IS NOT NULL
               ORDER BY relation, locktype, mode;" >> "$OUTPUT_DIR/locks_information.txt"

    # Total number of active locks
    echo "----------------------------------" > "$OUTPUT_DIR/active_locks.txt"
    echo " Total Active Locks" >> "$OUTPUT_DIR/active_locks.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/active_locks.txt"
    run_query "SELECT count(*) AS active_locks FROM pg_locks WHERE granted = true;" >> "$OUTPUT_DIR/active_locks.txt"

    # Max locks per transaction
    echo "----------------------------------" > "$OUTPUT_DIR/max_locks_per_transaction.txt"
    echo " Max Locks Per Transaction" >> "$OUTPUT_DIR/max_locks_per_transaction.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/max_locks_per_transaction.txt"
    run_query "SELECT name, setting, unit FROM pg_settings WHERE name = 'max_locks_per_transaction';" >> "$OUTPUT_DIR/max_locks_per_transaction.txt"

    # Check for partitions
    echo "----------------------------------" > "$OUTPUT_DIR/partitions.txt"
    echo " Partitioned Tables" >> "$OUTPUT_DIR/partitions.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/partitions.txt"
    run_query "SELECT parent.relname AS parent_table, 
               child.relname AS partition_name,
               pg_get_expr(child.relpartbound, child.oid) AS partition_expression
               FROM pg_inherits
               JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
               JOIN pg_class child ON pg_inherits.inhrelid = child.oid
               JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
               JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
               WHERE parent.relkind = 'p'
               ORDER BY parent.relname, child.relname;" >> "$OUTPUT_DIR/partitions.txt"

    # Check for auto-generated columns
    echo "----------------------------------" > "$OUTPUT_DIR/auto_generated_columns.txt"
    echo " Auto-Generated Columns" >> "$OUTPUT_DIR/auto_generated_columns.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/auto_generated_columns.txt"
    run_query "SELECT table_schema, table_name, column_name, data_type, generation_expression
               FROM information_schema.columns
               WHERE is_generated = 'ALWAYS'
               ORDER BY table_schema, table_name, column_name;" >> "$OUTPUT_DIR/auto_generated_columns.txt"

    # Check for event triggers
    echo "----------------------------------" > "$OUTPUT_DIR/event_triggers.txt"
    echo " Event Triggers" >> "$OUTPUT_DIR/event_triggers.txt"
    echo "----------------------------------" >> "$OUTPUT_DIR/event_triggers.txt"
    run_query "SELECT evtname AS trigger_name, 
               evtevent AS trigger_event, 
               evtowner::regrole AS trigger_owner,
               evtfoid::regproc AS trigger_function,
               evtenabled AS trigger_enabled
               FROM pg_event_trigger
               ORDER BY evtname;" >> "$OUTPUT_DIR/event_triggers.txt"
}

# Function to generate summary report
generate_report() {
    {
        echo "# PostgreSQL Pre-Check Report"
        echo "Date: $(date)"
        echo

        echo "## Version"
        cat "$OUTPUT_DIR/version.txt"
        echo

        echo "## Databases"
        cat "$OUTPUT_DIR/databases.txt"
        echo

        echo "## Database Sizes"
        cat "$OUTPUT_DIR/database_sizes.txt"
        echo

        echo "## Top 20 Table and Index Sizes"
        cat "$OUTPUT_DIR/table_index_sizes.txt"
        echo

        echo "## Notable Settings"
        grep -E "(max_connections|shared_buffers|work_mem|maintenance_work_mem|effective_cache_size)" "$OUTPUT_DIR/settings.txt"
        echo

        echo "## Installed Extensions"
        cat "$OUTPUT_DIR/extensions.txt"
        echo

        echo "## Current Activity Summary"
        grep -c . "$OUTPUT_DIR/activity.txt"
        echo "active connections"
        echo

        echo "## Index Count"
        wc -l < "$OUTPUT_DIR/indexes.txt"
        echo "total indexes"
        echo

        echo "## User Roles"
        cat "$OUTPUT_DIR/roles.txt"
        echo

        echo "## Logical Replication Support"
        cat "$OUTPUT_DIR/logical_replication.txt"
        echo

        echo "## Number of Replicas"
        cat "$OUTPUT_DIR/replica_count.txt"
        echo "active replicas"
        echo

        echo "## Long-Running Queries"
        cat "$OUTPUT_DIR/long_running_queries.txt"
        echo

        echo "## Max Locks Per Transaction"
        cat "$OUTPUT_DIR/max_locks_per_transaction.txt"
        echo

        echo "## Total Active Locks"
        cat "$OUTPUT_DIR/active_locks.txt"
        echo

        echo "## Locks Information"
        cat "$OUTPUT_DIR/locks_information.txt"
        echo

        echo "## Partitioned Tables"
        if [ -s "$OUTPUT_DIR/partitions.txt" ]; then
            cat "$OUTPUT_DIR/partitions.txt"
        else
            echo "No partitioned tables found."
        fi
        echo

        echo "## Auto-Generated Columns"
        if [ -s "$OUTPUT_DIR/auto_generated_columns.txt" ]; then
            cat "$OUTPUT_DIR/auto_generated_columns.txt"
        else
            echo "No auto-generated columns found."
        fi
        echo

        echo "## Event Triggers"
        if [ -s "$OUTPUT_DIR/event_triggers.txt" ]; then
            cat "$OUTPUT_DIR/event_triggers.txt"
        else
            echo "No event triggers found."
        fi
        echo

    } > "$OUTPUT_DIR/summary_report.md"

    echo "Summary report generated: $OUTPUT_DIR/summary_report.md"
}

# Function to perform a version-agnostic dump
perform_version_agnostic_dump() {
    echo "Performing database dump..."
    DUMP_FILE="$OUTPUT_DIR/database_dump.sql"
    
    # Dump schema (keep this part as it was)
    echo "-- Schema dump" > "$DUMP_FILE"
    PGPASSWORD=$PGPASSWORD psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -c "
    -- Schemas
    SELECT 'CREATE SCHEMA IF NOT EXISTS ' || quote_ident(nspname) || ';'
    FROM pg_namespace
    WHERE nspname NOT IN ('public', 'information_schema', 'pg_catalog', 'pg_toast');

    -- Tables
    SELECT 'CREATE TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || ' (' ||
           string_agg(quote_ident(a.attname) || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod) ||
                      CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END ||
                      CASE WHEN ad.adbin IS NOT NULL THEN ' DEFAULT ' || pg_get_expr(ad.adbin, ad.adrelid) ELSE '' END,
                      ', ') || ');'
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_attribute a ON c.oid = a.attrelid
    LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
    WHERE c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    GROUP BY n.nspname, c.relname, c.oid;

    -- Indexes
    SELECT pg_get_indexdef(i.indexrelid)
    FROM pg_index i
    JOIN pg_class c ON i.indexrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema');

    -- Views
    SELECT 'CREATE OR REPLACE VIEW ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || ' AS ' || 
           pg_get_viewdef(c.oid)
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE c.relkind = 'v' AND n.nspname NOT IN ('pg_catalog', 'information_schema');

    -- Functions
    SELECT 'CREATE OR REPLACE FUNCTION ' || quote_ident(n.nspname) || '.' || quote_ident(p.proname) || '(' ||
           pg_get_function_arguments(p.oid) || ') RETURNS ' || pg_get_function_result(p.oid) || ' AS $BODY$' ||
           pg_get_functiondef(p.oid) || '$BODY$ LANGUAGE ' || l.lanname || ';'
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    JOIN pg_language l ON p.prolang = l.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema');
    " >> "$DUMP_FILE"

    # Dump data (modified part)
    echo "-- Data dump" >> "$DUMP_FILE"
    PGPASSWORD=$PGPASSWORD psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -c "
    SELECT quote_ident(n.nspname) || '.' || quote_ident(c.relname) AS full_table_name
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema');" | while read -r table; do
        if [ -n "$table" ]; then
            echo "Dumping data for table: $table"
            echo "COPY $table FROM stdin;" >> "$DUMP_FILE"
            PGPASSWORD=$PGPASSWORD psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "COPY $table TO STDOUT;" >> "$DUMP_FILE"
            echo "\\." >> "$DUMP_FILE"
        fi
    done

    if [ $? -eq 0 ]; then
        echo "Database dump completed successfully. Dump file: $DUMP_FILE"
    else
        echo "Error: Database dump failed. Please check your permissions and connection details."
        return 1
    fi
}

# New function to capture \d+ output
capture_table_details() {
    echo "Capturing detailed table information..."
    TABLE_DETAILS_FILE="$OUTPUT_DIR/table_details.txt"
    
    echo "Detailed Table Information" > "$TABLE_DETAILS_FILE"
    echo "===========================" >> "$TABLE_DETAILS_FILE"
    echo "" >> "$TABLE_DETAILS_FILE"

    # Get list of all tables
    tables=$(PGPASSWORD=$PGPASSWORD psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -c "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') ORDER BY schemaname, tablename;")

    # Loop through each table and capture \d+ output
    while read -r table; do
        if [ -n "$table" ]; then
            echo "Table: $table" >> "$TABLE_DETAILS_FILE"
            echo "------------------------" >> "$TABLE_DETAILS_FILE"
            PGPASSWORD=$PGPASSWORD psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "\d+ $table" >> "$TABLE_DETAILS_FILE"
            echo "" >> "$TABLE_DETAILS_FILE"
        fi
    done <<< "$tables"

    echo "Detailed table information captured in: $TABLE_DETAILS_FILE"
}

# Modify the main function to include the new capture_table_details function
main() {
    echo "Collecting PostgreSQL information..."
    collect_pg_info

    echo "Capturing detailed table information..."
    capture_table_details

    echo "Generating summary report..."
    generate_report

    if [ "$PERFORM_DUMP" = true ]; then
        perform_version_agnostic_dump
    fi

    echo "Pre-check completed. Please review the summary report and table details."
}

# Parse command line arguments
PERFORM_DUMP=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*)
            PGHOST="${1#*=}"
            shift
            ;;
        --port=*)
            PGPORT="${1#*=}"
            shift
            ;;
        --user=*)
            PGUSER="${1#*=}"
            shift
            ;;
        --dbname=*)
            PGDATABASE="${1#*=}"
            shift
            ;;
        --password=*)
            export PGPASSWORD="${1#*=}"
            shift
            ;;
        --dump)
            PERFORM_DUMP=true
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Check if required parameters are set
if [ -z "$PGHOST" ] || [ -z "$PGUSER" ] || [ -z "$PGPASSWORD" ]; then
    echo "Error: Host, user, and password are required. Use --host=, --user=, and --password= parameters."
    exit 1
fi

# Run the main function
main
