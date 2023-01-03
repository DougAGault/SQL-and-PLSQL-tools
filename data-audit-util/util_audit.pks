create or replace PACKAGE util_audit AS 
--------------------------------------------------------------------------------
--
--  DESCRIPTION
--      Package to generate database objects and track audit information about changes to a specified table's data.
--
--  NOTES
--
--  * This structure was created to work specifically with table that have a single column primary key.
--
--  ASSUMPTIONS
--  
--  * All objects manipulated by this package exist in the current parsing schema.
--  * All triggers that Audit tables will be of the form BUID_<<TABLE_NAME>>_AUD
--  * ANY Triggers that have the above name signature will be affected by this package
--
--  DataTypes that can be Audited are: 
--
--      NUMBER
--      FLOAT
--      BINARY_FLOAT
--      BINARY_DOUBLE
--      VARCHAR2
--      CHAR
--      DATE
--      TIMESTAMP
--      TIMESTAMP W TIMEZONE
--      TIMESTAMP WITH LOCAL TIMEZONE
--      INTERVAL YEAR TO MONTH
--      INTERVAL DAY TO SECOND
--      CLOB
--
--  DataTypes EXCLUDED from audit are: 
--
--      ROWID
--      UROWID
--      BLOB
--      BFILE
--      NVARCHAR2
--      NCHAR
--      LONG
--      LONG_RAW
--      RAW
--
--    * Any varchar2 column values greater than 4000 in length will be stored in the audit tables CLOB column rather than in the varchar2 column
--
--    MODIFIED   (MM/DD/YYYY)
--      dgault    03/22/2022 - Current Oracle Version Created
--------------------------------------------------------------------------------
-- CREATE_AUDIT_TABLE
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will create the central logging table 
    --
    -- Arguments 
    --      p_action -       EXECUTE or GENERATE  
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    -- Objects Created are 
    --    UTIL_AUDIT_RECORDS - Table that holds all audit records for any tracked change. 
    -- 
    --    util_audit_record_id           number default on null to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') 
    --                                   constraint util_audit_records_id_pk primary key,
    --    transaction_id                 number,
    --    table_name                     varchar2(255 char),
    --    pk_value                       number,
    --    column_name                    varchar2(255 char),
    --    data_type                      varchar2(500 char),
    --    transaction_type               varchar2(6 char) constraint util_audit_re_transaction_t_cc
    --                                   check (transaction_type in ('INSERT','UPDATE','DELETE')),
    --    username                       varchar2(500 char),
    --    old_value                      varchar2(4000 char),
    --    new_value                      varchar2(4000 char),
    --    old_clob                       clob,
    --    new_clob                       clob,
    --    userenv                        varchar2(4000 char),
    --    audit_date                     date
    --
    -- example(s):
    --     util_audit.create_audit_table(p_action => 'GENERATE');
    --
    PROCEDURE create_audit_table (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- DROP_AUDIT_TABLE
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will DROP the central logging table 
    --
    -- Arguments 
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  DROPPED OBJECTS ARE  
    --    UTIL_AUDIT_RECORDS - Table that holds all audit records for any tracked change. 
    --
    --   
    -- example(s):
    --     util_audit.drop_audit_table(p_action => 'GENERATE');
    --
    PROCEDURE drop_audit_table (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- ADD_TABLE_AUDIT_TRIG
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will CREATE the trigger used to audit a table 
    --
    -- Arguments
    --      p_table_name     name of table to be audited
    --      p_columns        comma separated list of columns to audit
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  Trigger that will be CREATED will take the form of:   
    --    BIUD_<<p_table_name>>_AUD
    --   
    -- example(s):
    --     util_audit.add_table_audit_trig 
    --      (p_table_name => 'EMPLOYEES',
    --       p_columns    => 'FIRST_NAME,LAST_NAME,SALARY,COMMISSION_PCT',
    --       p_action     => 'GENERATE',
    --      );
    --
    --
    PROCEDURE add_table_audit_trig (
        p_table_name IN VARCHAR2
      , p_columns    IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- REMOVE_TABLE_AUDIT_TRIG
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will DROP the trigger used to audit a table 
    --
    -- Arguments 
    --      p_table_name     name of table 
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  Trigger that will be DROPPED will take the form of:   
    --    BIUD_<<p_table_name>>_AUD
    --   
    -- example(s):
    --     util_audit.remove_table_audit_trig 
    --      (p_table_name => 'EMPLOYEES',
    --       p_action     => 'GENERATE',
    --      );
    --
    PROCEDURE remove_table_audit_trig (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- ENABLE_AUDIT_FOR_TABLE
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will ENABLE auditing for a specified table 
    --
    -- NOTE: This will not create the trigger, only enable a trigger that already exists.
    --
    -- Arguments
    --      p_table_name     name of table to be audited
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  Trigger that will be ENABLED will take the form of:   
    --    BIUD_<<p_table_name>>_AUD - Trigger that captures audit data. 
    --   
    -- example(s):
    --     util_audit.enable_audit_for_table 
    --      (p_table_name => 'EMPLOYEES',
    --       p_action     => 'GENERATE',
    --      );
    --
    PROCEDURE enable_audit_for_table (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- DISABLE_AUDIT_FOR_TABLE
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will DISABLE auditing for a specified table
    --
    -- NOTE: This will not remove the trigger, only disable one that already exists.
    --
    -- Arguments
    --      p_table_name     name of table to be audited
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  Trigger that will be DISABLED will take the form of:    
    --    BIUD_<<p_table_name>>_AUD - Trigger that captures audit data. 
    --   
    -- example(s):
    --     util_audit.disable_audit_for_table 
    --      (p_table_name => 'EMPLOYEES',
    --       p_action     => 'GENERATE',
    --      );
    PROCEDURE disable_audit_for_table (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- ENABLE_ALL_AUDIT_TRIGGERS
--------------------------------------------------------------------------------
-- Generates (and optionally executes) a script that will ENABLE all audit triggers 
    --
    -- Arguments
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  CHANGED OBJECTS   
    --    BIUD_<<p_table_name>>_AUD - all triggers of this pattern will be ENABLED. 
    --   
    -- example(s):
    --     util_audit.enable_audit_for_table 
    --      (p_action     => 'GENERATE');
    --
    PROCEDURE enable_all_audit_triggers (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- DISABLE_ALL_AUDIT_TRIGGERS
--------------------------------------------------------------------------------
-- Generates (and optionally executes) a script that will DISABLE all audit triggers 
    --
    -- parameters
    --      p_action -       EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --  CHANGED OBJECTS   
    --    BIUD_<<p_table_name>>_AUD - all triggers of this pattern will be DISABLED. 
    --   
    -- example(s):
    --     util_audit.enable_audit_for_table 
    --      (p_action     => 'GENERATE');
    --
    PROCEDURE disable_all_audit_triggers (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    );
--------------------------------------------------------------------------------
-- REMOVE_AUDIT_RECS_FOR_TABLE
--------------------------------------------------------------------------------
-- Generates (and optionally executes) a script that will remove audit records from the central audit table. 
    --
    -- Arguments
    --      p_table_name     table name for which to remove audit records
    --      p_before_date    date before which to remove audit records 
    --      p_action         EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --
    --   
    -- example(s):
    --     util_audit.remove_audit_recs_for_table 
    --      (p_table_name => 'EMPLOYEES'
    --      ,p_before_date => '01-JAN-2022'
    --      ,p_action     => 'GENERATE');
    --
    PROCEDURE remove_audit_recs_for_table (
        p_table_name  IN VARCHAR2
      , p_before_date IN DATE DEFAULT sysdate
    );
--------------------------------------------------------------------------------
-- REMOVE_ALL_AUDIT_RECS
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will remove audit records from the central audit table. 
    --
    -- Arguments
    --      p_table_name     table name for which to remove audit records
    --      p_before_date    date before which to remove audit records 
    --      p_action         EXECUTE or GENERATE 
    --                       EXECUTE will execute the script immediately, creating the objects.
    --                       GENERATE will emit the script to the OWA HTP buffer. 
    --   
    -- 
    --
    --   
    -- example(s):
    --     util_audit.remove_audit_recs_for_table 
    --      (p_before_date => '01-JAN-2022'
    --      ,p_action     => 'GENERATE');
    --
    PROCEDURE remove_all_audit_recs (
        p_before_date IN DATE DEFAULT sysdate
    );
--------------------------------------------------------------------------------
-- TABLE_IS_AUDITED
--------------------------------------------------------------------------------
    -- Generates (and optionally executes) a script that will remove audit records from the central audit table. 
    --
    -- Arguments
    --      p_table_name     table name for which to remove audit records
    --     
    -- Returns
    --      BOOLEAN - Whether the table is audited
    --   
    -- example(s):
    --   l_bool :=  util_audit.table_is_audited 
    --      (p_table_name => 'EMPLOYEES');
    --
    FUNCTION table_is_audited (
        p_table_name IN VARCHAR2
    ) RETURN BOOLEAN;

--------------------------------------------------------------------------------
-- CAPTURE_AUDIT
--------------------------------------------------------------------------------
    -- Called from the generated triggers to actually capture the changes to a record.  
    --
    -- Arguments
    --      p_transaction_json     A JSON object that contains all the changes initiated for an Insert, Update or Delete
    --
    -- The JSON Data structure will look like this. 
    --        {
    --          "table_name": "EMPLOYEES",
    --          "trans_type": "UPDATE",
    --          "audit_date": "01-JAN-2022",
    --          "user_name": "douglas.gault@oracle.com",
    --          "trasaction_id": "123123123980198309280"
    --          "pk_value": 123123123123,
    --          "columns": [
    --            {
    --              "column_name": "FIRST_NAME",
    --              "data_type": "VARCHAR2",
    --              "old_value": "RANDALL",
    --              "new_value": "RANDY"
    --            },
    --            {
    --              "column_name": "SALARY",
    --              "datatype": "NUMBER",
    --              "old_value": "1500",
    --              "new_value": "2000"

    --            }
    --          ]
    --        }

    --   
    --
    PROCEDURE capture_audit (
        p_transaction_json IN json_object_t
    );
--
--
END util_audit;