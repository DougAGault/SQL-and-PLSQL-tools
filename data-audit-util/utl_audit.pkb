create or replace PACKAGE BODY util_audit AS
--------------------------------------------------------------------------------
--
--    DESCRIPTION
--      Package to generate database objects to track audit information about changes to a specified table's data.
--
--
--    NOTES
--
--    MODIFIED   (MM/DD/YYYY)
--      dgault    03/22/2022 - Current Oracle Version Created
--
--------------------------------------------------------------------------------

-- ==================================================================================
--  P R I V A T E   M E T H O D S 
-- ==================================================================================
    g_ignored_columns VARCHAR2(32767);

-------------------------------------------------------------------------------------
-- TRIM_TABLE_NAME
-------------------------------------------------------------------------------------
-- returns the first 20 characters of the table name passed
-------------------------------------------------------------------------------------
    FUNCTION trim_table_name (
        p_table_name IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN substr(p_table_name, 1, 20);
    END trim_table_name;
-------------------------------------------------------------------------------------
-- OUTPUT_SQL
-------------------------------------------------------------------------------------
-- Either EXECUTE the SQL or print it to the OWA Buffer
-------------------------------------------------------------------------------------
    PROCEDURE output_sql (
        p_sql    IN VARCHAR2
      , p_action IN VARCHAR2
    ) IS
        cursor_name    INTEGER;
        rows_processed INTEGER;
    BEGIN
        IF p_action = 'EXECUTE' THEN
            BEGIN
                cursor_name    := dbms_sql.open_cursor;
                dbms_sql.parse(cursor_name, p_sql, dbms_sql.native);
                rows_processed := dbms_sql.execute(cursor_name);
                dbms_sql.close_cursor(cursor_name);
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_sql.close_cursor(cursor_name);
                    RAISE;
            END;

        ELSIF p_action = 'GENERATE' THEN
            dbms_output.put_line(p_sql || chr(10) || chr(10));
        END IF;
    END output_sql;
-- ==================================================================================
--  P U B L I C   M E T H O D S 
-- ==================================================================================
--------------------------------------------------------------------------------
-- CREATE_AUDIT_TABLE
--------------------------------------------------------------------------------
-- Creates the central logging table 
-------------------------------------------------------------------------------------
    PROCEDURE create_audit_table (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql VARCHAR2(32767);
    BEGIN
    --
    -- Main Table Create Script
    --
        v_sql := q'!create table UTIL_AUDIT_RECORDS ( !' || chr(13);
        v_sql := v_sql || q'!util_audit_record_id  number default on null to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX')!' || chr(13);
        v_sql := v_sql || q'!                      constraint util_audit_records_id_pk primary key,!' || chr(13);
        v_sql := v_sql || q'!transaction_id        number,!' || chr(13);
        v_sql := v_sql || q'!table_name            varchar2(255),!' || chr(13);
        v_sql := v_sql || q'!pk_value              number,!' || chr(13);
        v_sql := v_sql || q'!column_name           varchar2(255),!' || chr(13);
        v_sql := v_sql || q'!data_type             varchar2(500),!' || chr(13);
        v_sql := v_sql || q'!transaction_type      varchar2(6) constraint util_audit_re_transaction_t_cc!' || chr(13);
        v_sql := v_sql || q'!                      check (transaction_type in ('INSERT','UPDATE','DELETE')),!' || chr(13);
        v_sql := v_sql || q'!username              varchar2(500),!' || chr(13);
        v_sql := v_sql || q'!old_value             varchar2(4000),!' || chr(13);
        v_sql := v_sql || q'!new_value             varchar2(4000),!' || chr(13);
        v_sql := v_sql || q'!old_clob              clob,!' || chr(13);
        v_sql := v_sql || q'!new_clob              clob,!' || chr(13);
        v_sql := v_sql || q'!userenv               varchar2(4000),!' || chr(13);
        v_sql := v_sql || q'!audit_date            date!' || chr(13);
        v_sql := v_sql || q'!)!';
        output_sql(p_sql => v_sql, p_action => p_action);
    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20001, 'create_audit_table' || ' - ' || dbms_utility.format_error_backtrace, true);
    END create_audit_table;
--------------------------------------------------------------------------------
-- DROP_AUDIT_TABLE
--------------------------------------------------------------------------------
-- Drops the central Logging table - USE WITH CAUTION
-------------------------------------------------------------------------------------
    PROCEDURE drop_audit_table (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql VARCHAR2(32767);
        table_does_not_exist EXCEPTION;
        PRAGMA exception_init ( table_does_not_exist, -942 );
    BEGIN
        v_sql := 'drop table UTIL_AUDIT_RECORDS';
        BEGIN
            output_sql(p_sql => v_sql, p_action => p_action);
        EXCEPTION
            WHEN table_does_not_exist THEN
                NULL;
            WHEN OTHERS THEN
                raise_application_error(-20001, 'drop_audit_table' || ' - ' || dbms_utility.format_error_backtrace, true);
        END;

    END drop_audit_table;
--------------------------------------------------------------------------------
-- ADD_TABLE_AUDIT_TRIG 
--------------------------------------------------------------------------------
-- Adds a trigger to audit specific columns in a table 
--------------------------------------------------------------------------------
    PROCEDURE add_table_audit_trig (
        p_table_name IN VARCHAR2
      , p_columns    IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql        VARCHAR2(32767);
        v_table_name VARCHAR2(500) := upper(p_table_name);
        v_columns    VARCHAR2(32767) := ',' || replace(upper(p_columns), ' ', NULL) || ','; -- Replacing spaces with nulls and adding leading and traling comma
        v_pk_col     VARCHAR2(500);
    BEGIN
    --
    -- Get all the prerequisite data that we need
    --
    -- The following code will get the primary key column for the table in questions to use in the call to AUDIT.
    --
    -- NOTE: This was written to to work with tables with a single column surrogate primary key.
        BEGIN
            SELECT cols.column_name
              INTO v_pk_col
              FROM user_constraints  cons
                 , user_cons_columns cols
             WHERE cols.table_name = v_table_name
               AND cons.constraint_type = 'P'
               AND cons.constraint_name = cols.constraint_name
               AND cons.owner           = cols.owner
             ORDER BY cols.position;

        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    --
    -- Build out Trigger code 
    --
    -- the first part is the trigger preamble and the initial variables right up to the BEGIN clause.
    --
        v_sql := q'! create or replace trigger AIUD_!' || trim_table_name(v_table_name) || q'!_AUD!' || chr(13);

        v_sql := v_sql || q'!  after insert or update or delete !' || chr(13);
        v_sql := v_sql || q'!  on !' || v_table_name || chr(13);
        v_sql := v_sql || q'!  for each row !' || chr(13);
        v_sql := v_sql || q'!  declare !' || chr(13);
        v_sql := v_sql || q'!   l_txn_id number; !' || chr(13);
        v_sql := v_sql || q'!   v_audit_json json_object_t := new json_object_t; !' || chr(13);
        v_sql := v_sql || q'!   v_temp_json  json_object_t := new json_object_t; !' || chr(13);
        v_sql := v_sql || q'!   v_json_array json_array_t  := new json_array_t; !' || chr(13);
        v_sql := v_sql || q'!   v_empty_json json_object_t := new json_object_t; !' || chr(13);
        v_sql := v_sql || q'!   l_trigger_action varchar2(6); !' || chr(13);
    --
        v_sql := v_sql || q'!  begin !' || chr(13);
    --
    -- This section creates the transaction id that will link all the individual audit records together for a single transaction.
    --
        v_sql := v_sql || q'!     -- !' || chr(13);
        v_sql := v_sql || q'!     -- Generate a transaction ID for this I/U/D event !' || chr(13);
        v_sql := v_sql || q'!     -- !' || chr(13);
        v_sql := v_sql || q'!     l_txn_id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');  !' || chr(13);
        v_sql := v_sql || q'!     -- !' || chr(13);
    --
    -- Figure out which type of transaction this is 
    --
        v_sql := v_sql || q'!     IF INSERTING THEN  !' || chr(13);
        v_sql := v_sql || q'!       l_trigger_action := 'INSERT';  !' || chr(13);
        v_sql := v_sql || q'!     ELSIF UPDATING then   !' || chr(13);
        v_sql := v_sql || q'!       l_trigger_action := 'UPDATE';  !' || chr(13);
        v_sql := v_sql || q'!     ELSIF DELETING then   !' || chr(13);
        v_sql := v_sql || q'!       l_trigger_action := 'DELETE';  !' || chr(13);
        v_sql := v_sql || q'!     END IF; !' || chr(13);
    --
    -- Next we start createing the JSON object. 
    --  * first we create the JSON elements that are common to the entire transaction 
    --
        v_sql := v_sql || q'!     -- Create the base JSON object with the top level details !' || chr(13);
        v_sql := v_sql || q'!     -- !' || chr(13);
    --  ** Table Name 
        v_sql := v_sql || q'!     v_audit_json.put('table_name', '!' || v_table_name || q'!'); !' || chr(13);
    -- ** Transaction Type (Insert, Update or Delete )
        v_sql := v_sql || q'!     v_audit_json.put('trans_type', l_trigger_action); !' || chr(13);
    -- ** Audit Date
        v_sql := v_sql || q'!     v_audit_json.put('audit_date', sysdate); !' || chr(13);
    -- ** User
        v_sql := v_sql || q'!     v_audit_json.put('user_name', nvl(v( 'APP_USER' ),user)); !' || chr(13);
    -- ** Transaction id 
        v_sql := v_sql || q'!     v_audit_json.put('transaction_id', l_txn_id); !' || chr(13);
    -- ** Primary Key data 
        v_sql := v_sql || q'!     -- Pick the value of the PK if its available !' || chr(13);
        v_sql := v_sql || q'!     IF INSERTING then !' || chr(13);
        v_sql := v_sql || q'!          v_audit_json.put('pk_value', :new.!' || v_pk_col || q'!); !' || chr(13);

        v_sql := v_sql || q'!     ELSE    !' || chr(13);
        v_sql := v_sql || q'!          v_audit_json.put('pk_value', :old.!' || v_pk_col || q'!); !' || chr(13);

        v_sql := v_sql || q'!     END IF; !' || chr(13);
    
    --
    -- Loop through all the columns of the table and match to the columns the user requested to audit. 
    -- 
        FOR r IN (
            SELECT column_name
                 , data_type
                 , data_length
              FROM all_tab_columns
             WHERE table_name = p_table_name
               AND ( data_type IN ( 'NUMBER', 'VARCHAR2', 'CHAR', 'FLOAT', 'DATE'
                                  , 'BINARY_FLOAT', 'BINARY_DOUBLE', 'CLOB' )
                OR data_type LIKE 'TIMESTAMP%' )
        ) LOOP
    --
    -- If the current column name is  in the list of columns to include, then add it to the trigger code. 
    --
            IF instr(v_columns, ',' || r.column_name || ',') > 0 THEN
                v_sql := v_sql || q'! IF :NEW.!' || r.column_name || q'! != :OLD.!' || r.column_name
                         || q'! OR (:NEW.!' || r.column_name || q'! is not null and :OLD.!' || r.column_name || q'! is null)!'
                         || q'! OR (:NEW.!' || r.column_name || q'! is null and :OLD.!' || r.column_name || q'! is not null)!'
                         || q'! OR DELETING or INSERTING THEN !' || chr(13);

                v_sql := v_sql || q'!       -- Clear the temporary JSON object !' || chr(13);
                v_sql := v_sql || q'!       v_temp_json := v_empty_json; !' || chr(13);
                v_sql := v_sql || q'!       -- add the details for the change !' || chr(13);
                v_sql := v_sql || q'!       v_temp_json.put('column_name', '!' || r.column_name || q'!'); !' || chr(13);

                v_sql := v_sql || q'!       v_temp_json.put('data_type',  '!' || r.data_type || q'!'); !' || chr(13);

                v_sql := v_sql || q'!       v_temp_json.put('old_value', :old.!' || r.column_name || q'!); !' || chr(13);

                v_sql := v_sql || q'!       v_temp_json.put('new_value', :new.!' || r.column_name || q'!); !' || chr(13);

                v_sql := v_sql || q'!       -- Add the object to the array  !' || chr(13);
                v_sql := v_sql || q'!       v_json_array.append(v_temp_json); !' || chr(13);
                v_sql := v_sql || q'!     END IF;!' || chr(13);
            END IF;
    --
        END LOOP;
    --
    -- Now add the array to the final JSON document 
    --
        v_sql := v_sql || q'!     -- !' || chr(13);
        v_sql := v_sql || q'!     -- Add the array of changed to the JSON object !' || chr(13);
        v_sql := v_sql || q'!     --    !' || chr(13);
        v_sql := v_sql || q'!     v_audit_json.put('columns', treat(v_json_array as json_array_t)); !' || chr(13);
    --
    -- and call the util_audit package to capture the changes
    --
        v_sql := v_sql || q'!     -- !' || chr(13);
        v_sql := v_sql || q'!     -- Log the changes !' || chr(13);
        v_sql := v_sql || q'!     -- !' || chr(13);
        v_sql := v_sql || q'!     util_audit.capture_audit(p_transaction_json => v_audit_json); !' || chr(13);
        v_sql := v_sql || q'!-- !' || chr(13);
        v_sql := v_sql || q'!END; !' || chr(13);
        output_sql(p_sql => v_sql, p_action => p_action);
    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20001, 'add_table_audit_trig' || ' - ' || dbms_utility.format_error_backtrace, true);
    END add_table_audit_trig;
--------------------------------------------------------------------------------
-- REMOVE_TABLE_AUDIT_TRIG
--------------------------------------------------------------------------------
-- Removes trigger that audits specific columns in a table 
--------------------------------------------------------------------------------
    PROCEDURE remove_table_audit_trig (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql        VARCHAR2(32767);
        v_table_name VARCHAR2(500) := upper(p_table_name);
    BEGIN
        IF table_is_audited(v_table_name) THEN
            v_sql := q'!drop trigger "AIUD_!' || trim_table_name(v_table_name) || q'!_AUD"!';
            --
            output_sql(p_sql => v_sql, p_action => p_action);
        END IF;
    END remove_table_audit_trig;

--------------------------------------------------------------------------------
-- ENABLE_AUDIT_FOR_TABLE
--------------------------------------------------------------------------------
-- Enables trigger that audits the specified table 
--------------------------------------------------------------------------------
    PROCEDURE enable_audit_for_table (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql        VARCHAR2(32767);
        v_table_name VARCHAR2(500) := upper(p_table_name);
    BEGIN
        IF table_is_audited(v_table_name) THEN
            v_sql := q'!alter trigger "AIUD_!' || trim_table_name(v_table_name) || q'!_AUD" enable!';
            --
            output_sql(p_sql => v_sql, p_action => p_action);
        END IF;
    END enable_audit_for_table;
--------------------------------------------------------------------------------
-- DISABLE_AUDIT_FOR_TABLE
--------------------------------------------------------------------------------
-- Disables trigger that audits the specified table 
--------------------------------------------------------------------------------
    PROCEDURE disable_audit_for_table (
        p_table_name IN VARCHAR2
      , p_action     IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql        VARCHAR2(32767);
        v_table_name VARCHAR2(500) := upper(p_table_name);
    BEGIN
        IF table_is_audited(v_table_name) THEN
            v_sql := q'!alter trigger "AIUD_!' || trim_table_name(v_table_name) || q'!_AUD" disable!';
            --
            output_sql(p_sql => v_sql, p_action => p_action);
        END IF;
    END disable_audit_for_table;
--------------------------------------------------------------------------------
-- ENABLE_ALL_AUDIT_TRIGGERS
--------------------------------------------------------------------------------
--  Enables all AUDIT Triggers that adhere to this packages naming convetion
--------------------------------------------------------------------------------
    PROCEDURE enable_all_audit_triggers (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql VARCHAR2(32767);
    BEGIN
        FOR trigger_list IN (
            SELECT table_name
              FROM user_triggers
             WHERE base_object_type = 'TABLE'
               AND trigger_name LIKE 'AIUD_%_AUD'
               AND status != 'ENABLED'
        ) LOOP
            v_sql := q'!alter trigger "AIUD_!' || trim_table_name(trigger_list.table_name) || q'!_AUD" enable!';
            --
            output_sql(p_sql => v_sql, p_action => p_action);
        END LOOP;
    END enable_all_audit_triggers;
--------------------------------------------------------------------------------
-- DISABLE_ALL_AUDIT_TRIGGERS
--------------------------------------------------------------------------------
--  DISABLES all AUDIT Triggers that adhere to this packages naming convetion
--------------------------------------------------------------------------------
    PROCEDURE disable_all_audit_triggers (
        p_action IN VARCHAR2 DEFAULT 'GENERATE'
    ) IS
        v_sql VARCHAR2(32767);
    BEGIN
        FOR trigger_list IN (
            SELECT table_name
              FROM user_triggers
             WHERE base_object_type = 'TABLE'
               AND trigger_name LIKE 'AIUD_%_AUD'
               AND status = 'ENABLED'
        ) LOOP
            v_sql := q'!alter trigger "AIUD_!' || trim_table_name(trigger_list.table_name) || q'!_AUD" disable!';
            --
            output_sql(p_sql => v_sql, p_action => p_action);
        END LOOP;
    END disable_all_audit_triggers;
--------------------------------------------------------------------------------
-- REMOVE_AUDIT_RECS_FOR_TABLE
--------------------------------------------------------------------------------
--  Removes audit records for a specified table that have an occurance date 
--  before the date specified.
--------------------------------------------------------------------------------
    PROCEDURE remove_audit_recs_for_table (
        p_table_name  IN VARCHAR2
      , p_before_date IN DATE DEFAULT sysdate
    ) IS
        v_table_name VARCHAR2(500) := upper(p_table_name);
    BEGIN
        $if util_audit_control.is_installed $then
        DELETE FROM util_audit_records
         WHERE table_name = v_table_name
           AND ( audit_date < p_before_date
            OR p_before_date IS NULL );
       $else
       null;
       $end

    END remove_audit_recs_for_table;
--------------------------------------------------------------------------------
-- REMOVE_ALL_AUDIT_RECS
--------------------------------------------------------------------------------
--  Removes audit records for ALL TABLES that have an occurance date 
--  before the date specified.
--------------------------------------------------------------------------------
    PROCEDURE remove_all_audit_recs (
        p_before_date IN DATE DEFAULT sysdate
    ) IS
    BEGIN
        $if util_audit_control.is_installed $then
        DELETE FROM util_audit_records
         WHERE ( audit_date < p_before_date
            OR p_before_date IS NULL );
        $else
        null;
        $end

    END remove_all_audit_recs;
--------------------------------------------------------------------------------
-- TABLE_IS_AUDITED
--------------------------------------------------------------------------------
--  Returns a boolean based on whether the table has an audit trigger 
--  that matches the naming convention of this package.
--------------------------------------------------------------------------------
    FUNCTION table_is_audited (
        p_table_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_table_has_trigger BOOLEAN := false;
        v_table_name        VARCHAR2(500) := upper(p_table_name);
    BEGIN
        FOR i IN (
            SELECT 1 result
              FROM user_triggers
             WHERE base_object_type = 'TABLE'
               AND table_name = v_table_name
               AND trigger_name LIKE 'AIUD_%_AUD'
        ) LOOP
            v_table_has_trigger := true;
        END LOOP;
        --
        RETURN v_table_has_trigger;
    END table_is_audited;

--------------------------------------------------------------------------------
-- CAPTURE_AUDIT
--------------------------------------------------------------------------------
-- Captures the details of a record change in the central audit log table
--------------------------------------------------------------------------------
    PROCEDURE capture_audit (
        p_transaction_json IN json_object_t
    ) IS
      l_userenv VARCHAR2(4000) := nvl(sys_context('USERENV','MODULE'),'<<Not Set>>')||'|'||nvl(sys_context('USERENV','ACTION'),'<<Not Set>>');
      $if dbms_db_version.version > 19 $then
      l_json    JSON := p_transaction_json.to_json; -- Can only be used in 21c and above
      $else
      l_clob    clob := p_transaction_json.to_clob; -- To be used up to 19c
      $end
    BEGIN
    
    $if util_audit_control.is_installed $then
    INSERT INTO util_audit_records (
        transaction_id
        , table_name
        , pk_value
        , transaction_type
        , username
        , column_name
        , data_type
        , old_value
        , new_value
        , old_clob
        , new_clob
        , userenv
        , audit_date
    )
        SELECT transaction_id
             , table_name
             , pk_value
             , transaction_type
             , username
             , column_name
             , data_type
             -- OLD VALUE
             ,case data_type when 'CLOB' then null else j.old_value
               end as old_value
             -- NEW VALUE
             ,case data_type when 'CLOB' then null else j.new_value
               end as new_value
             -- OLD CLOB
             ,case data_type when 'CLOB' then j.old_value else null
               end as old_clob
             -- NEW CLOB
             ,case data_type when 'CLOB' then j.new_value else null
               end as new_clob
             , l_userenv  -- value defined above
             , sysdate    -- Right Now
          FROM json_table ( 
                    $if dbms_db_version.version > 19 $then
                    l_json, '$'         -- For 21c and above .. Comment out for earlier versions
                    $else
                    l_clob, '$'       -- For 19c and below .. Comment out for 21c and beyond.
                    $end
                    COLUMNS (
                      transaction_id    NUMBER PATH '$.transaction_id'
                     ,table_name        varchar2(255) PATH '$.table_name'
                     ,pk_value          number PATH '$.pk_value'
                     ,transaction_type  varchar2(6) path '$.trans_type'
                     ,username          varchar2(500) PATH '$.user_name'
                    , NESTED PATH '$.columns[*]'
                      COLUMNS (column_name varchar2(255) PATH '$.column_name'
                              ,data_type VARCHAR2(500) PATH '$.data_type'
                              ,old_value CLOB PATH '$.old_value'
                              ,new_value CLOB PATH '$.new_value'
                            )
                    )
                )
            j;
    $else
    null;
    $end

    END capture_audit;
--
--
END util_audit;
/