# PG-PRECHECKS

~~~
NAME
    pg-prechecks - Summarizes information about your PostgreSQL instance to help
    prepare migration into Neon

SYNOPSIS
  Usage: pg-prechecks [OPTIONS]

  pg-prechecks summarizes the status and configuration of a PostgreSQL database
    server so that you can learn about it at a glance, and it allows
    you to share the relevant information with Neon. It is not a
    tuning tool or diagnosis tool. It produces a report that is easy to diff
    and can be pasted into emails without losing the formatting. It should
    work well on any modern UNIX systems.

  pg-prechecks is a heavily modified version of pt-pg-summary, which is
    part of the Percona Toolkit.

RISKS 
    pg-prechecks is designed to connect to your live database environment,
    execute queries to collect the relevant information, and
    process/summarize the data without further impacting your database
    environment. While this script is well-tested, any database tool can pose
    a risk to your database environment.

  Before using this tool, please:
    - Read the tool's documentation
    - Test the tool on a non-production server first
    - Backup your production server and verify the backups

## Security Note

This script requires database credentials.
Use it in a secure environment and avoid exposing passwords in command-line arguments on shared systems.
~~~

## Features 

- Collects version information
- Lists databases and their sizes
- Reports top 20 table and index sizes
- Retrieves important configuration settings
- Lists installed extensions
- Provides a summary of current database activity
- Counts total indexes
- Lists user roles
- Checks for logical replication support
- Reports the number of active replicas
- Identifies long-running queries
- Reports on locks information
- Checks for primary keys, total number of active locks, max. no. of locks that a transaction can have
- Checks if partitions exist 
- Checks If auto-generated columns exist
- Checks for event triggers 
- Checks if (icu) localization features are used
- Optionally performs a version-agnostic database dump

## Prerequisites

- PostgreSQL client (`psql`) installed and accessible from the command line
- Network access to the target PostgreSQL instance (RDS)

## Usage

1. Make the script executable:
   ```
   chmod +x pg-prechecks.sh
   ```

2. Run the script with the required parameters:
   ```
   ./pg-prechecks --host=your-db-host --user=your-username --password=your-password [options]
   ```

   Required parameters:
   - `--host`: The hostname or IP address of your PostgreSQL instance
   - `--user`: The username to connect to the database
   - `--password`: The password for the specified user

   Optional parameters:
   - `--port`: The port number (default is 5432)
   - `--dbname`: The name of the database to connect to (default is "postgres")

## Output

The script creates a directory named `pg_precheck_YYYYMMDD_HHMMSS` containing:

- Individual text files with detailed information for each checked aspect
- A summary report file `summary_report.md` in Markdown format



## Example Output

After running the script, you'll get a summary report in Markdown format. Here's a sample of what it might look like:

```
PostgreSQL Pre-Check Report
Date: 2023-05-15 14:30:22

## Version
PostgreSQL 13.4 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit

## Databases
postgres
template1
template0
myapp

## Database Sizes
myapp     | 2.3 GB
postgres  | 8.5 MB
template1 | 7.9 MB
template0 | 7.9 MB

## Top 20 Table and Index Sizes
public.users           | 1.2 GB  | 980 MB  | 220 MB
public.orders          | 800 MB  | 650 MB  | 150 MB
public.products        | 500 MB  | 400 MB  | 100 MB
...

## Notable Settings
max_connections        | 100
shared_buffers         | 128MB
work_mem               | 4MB
maintenance_work_mem   | 64MB
effective_cache_size   | 4GB

## Installed Extensions
plpgsql
pg_stat_statements
pgcrypto

## Current Activity Summary
15 active connections

## Index Count
142 total indexes

## User Roles
postgres|t|t|t|t|t|t|t|t|t|t|
myapp_user|f|t|f|f|f|f|f|f|f|f|
...

## Logical Replication Support
Supported

## Number of Replicas
2 active replicas

## Long-Running Queries
pid  | duration | query
-----+----------+-------------------------------
1234 | 00:10:15 | SELECT * FROM large_table ...
5678 | 00:08:30 | UPDATE users SET last_login ...

## Locks Information
pid  | locktype | mode        | granted | table_name | query
-----+----------+-------------+---------+------------+------------------------
1234 | relation | AccessShare | t       | users      | SELECT * FROM users ...
5678 | relation | RowExclusive| t       | orders     | UPDATE orders SET ...
```

table_details.txt
```
Detailed Table Information
===========================

Table: public.branches
------------------------
                                             Table "public.branches"
      Column       | Type | Collation | Nullable | Default | Storage  | Compression | Stats target | Description 
-------------------+------+-----------+----------+---------+----------+-------------+--------------+-------------
 branch_name       | text |           |          |         | extended |             |              | 
 connection_string | text |           |          |         | extended |             |              | 
Publications:
    "peerdb_publication"
Access method: heap


Table: public.pgbench_accounts
------------------------
                                   Partitioned table "public.pgbench_accounts"
  Column  |     Type      | Collation | Nullable | Default | Storage  | Compression | Stats target | Description 
----------+---------------+-----------+----------+---------+----------+-------------+--------------+-------------
 aid      | bigint        |           | not null |         | plain    |             |              | 
 bid      | integer       |           |          |         | plain    |             |              | 
 abalance | integer       |           |          |         | plain    |             |              | 
 filler   | character(84) |           |          |         | extended |             |              | 
Partition key: RANGE (aid)
Publications:
    "peerdb_publication"
Partitions: pgbench_accounts_10 FOR VALUES FROM ('6312510001') TO (MAXVALUE),
            pgbench_accounts_2 FOR VALUES FROM ('701390001') TO ('1402780001'),
            pgbench_accounts_3 FOR VALUES FROM ('1402780001') TO ('2104170001'),
            pgbench_accounts_4 FOR VALUES FROM ('2104170001') TO ('2805560001'),
            pgbench_accounts_5 FOR VALUES FROM ('2805560001') TO ('3506950001'),
            pgbench_accounts_6 FOR VALUES FROM ('3506950001') TO ('4208340001'),
            pgbench_accounts_7 FOR VALUES FROM ('4208340001') TO ('4909730001'),
            pgbench_accounts_8 FOR VALUES FROM ('4909730001') TO ('5611120001'),
            pgbench_accounts_9 FOR VALUES FROM ('5611120001') TO ('6312510001')

```

This summary provides a quick overview of your PostgreSQL instance's state, including version, database sizes, table sizes, settings, activity, and potential issues like long-running queries or locks.

# Troubleshooting
If you encounter any issues:
1. Ensure you have the correct permissions to access the database.
2. Check that the PostgreSQL client tools are correctly installed and configured.
3. Verify that you can connect to the database manually using the same credentials.


```
ABOUT PERCONA TOOLKIT
    This tool is a heavily modified version of pt-pg-summary, which is
    part of Percona Toolkit, a collection of advanced command-line tools for
    PostgreSQL developed by Percona. Percona Toolkit was forked from two projects
    in June, 2013: Maatkit and Aspersa. Those projects were created by Baron
    Schwartz and primarily developed by him and Daniel Nichter. Visit
    <http://www.percona.com/software/> to learn about other free,
    open-source software from Percona.

COPYRIGHT, LICENSE, AND WARRANTY
    This program is copyright 2011-2021 Percona LLC and/or its affiliates,
    2010-2011 Baron Schwartz.

    THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
    WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, version 2; OR the Perl Artistic License. On
    UNIX and similar systems, you can issue `man perlgpl' or `man
    perlartistic' to read these licenses.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
```

