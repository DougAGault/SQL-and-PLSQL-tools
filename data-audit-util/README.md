# Data Audit Utility

This package was born out of a need to undestand what happened to a specific row of data over time and the ability to track the changes that were made and by whom. And is the spirit of writing code that generates code, this package will generate all the database objects necessary to track audit information about changes to a specified table's data.

## Assumptions

- All objects manipulated by this package exist in the current parsing schema.
- All triggers that Audit tables will be of the form BUID\_<<TABLE_NAME>>\_AUD
- ANY Triggers that have the above name signature will be affected by this package

## Limitations

DataTypes that can be Audited are:

      NUMBER
      FLOAT
      BINARY_FLOAT
      BINARY_DOUBLE
      VARCHAR2
      CHAR
      DATE
      TIMESTAMP
      TIMESTAMP W TIMEZONE
      TIMESTAMP WITH LOCAL TIMEZONE
      INTERVAL YEAR TO MONTH
      INTERVAL DAY TO SECOND
      CLOB

DataTypes EXCLUDED from audit are:

      ROWID
      UROWID
      BLOB
      BFILE
      NVARCHAR2
      NCHAR
      LONG
      LONG_RAW
      RAW

    * Any varchar2 column values greater than 4000 in length will be stored in the audit tables CLOB column rather than in the varchar2 column

## Object Shapes

### Audit Table

There will be a single audit table that captures the changes for all audited schema tables. The structure of the table is as follows:

    UTIL_AUDIT_RECORDS - Table that holds all audit records for any tracked change.

    util_audit_record_id           number default on null to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX')
                                   constraint util_audit_records_id_pk primary key,
    transaction_id                 number,
    table_name                     varchar2(255 char),
    pk_value                       number,
    column_name                    varchar2(255 char),
    data_type                      varchar2(500 char),
    transaction_type               varchar2(6 char) constraint util_audit_re_transaction_t_cc
                                   check (transaction_type in ('INSERT','UPDATE','DELETE')),
    username                       varchar2(500 char),
    old_value                      varchar2(4000 char),
    new_value                      varchar2(4000 char),
    old_clob                       clob,
    new_clob                       clob,
    userenv                        varchar2(4000 char),
    audit_date                     date

### Audit Trigger

For each table being audited a trigger with the following name will be created.

      BIUD_<<p_table_name>>_AUD

## TO DO

- Refactor CAPTURE_AUDIT to use dynamic SQL. This will fix the issue of the package becoming invalid on first load and compile
- Refactor the entire package to save not only the changes to the record, but a JSON object that represents the current state of the record after the changes take affect.
- Take into account any linked lookups and save the current values of those lookups.
