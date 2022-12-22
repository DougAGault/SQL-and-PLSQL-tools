# Seed Data Merge Script

There are many times when you're coding an application where there is a requirement for seed data that is required for the system to run correctly. If the seed data is changed or missing, some programming functions will fail due to the missing data.

Normally this system will not have a way to "maintain" this seed data through any type of UI. This facilitates the need to have scripts you can run to get the seed data into the right tables.

However there is a problem - If you write simple `INSERT` scripts and the data already exists in the target table, you get errors. So, it just makes sense to write a `MERGE` statement that will add any missing data and reset any data that might have been changed.

Since this happens quite a lot for me, I've written a script that will emit the `MERGE` script for me. You can pick up a copy of the script [here on my GitHub](https://github.com/DougAGault/SQL-and-PLSQL-tools/tree/main/seed-data-merge).

## Assumptions

1.  You're going to be running this in an environment that actually has the data you want to extract and keep This could be DEV, UAT, PROD - whatever. What the script will do is extract the data from the indicated table from the target environment and create a script to allow you to reinstate it later.
2.  These are probably standard lookup tables that aren't very complex. This script accounts for `DATE`, `NUMBER`, and `VARCHAR` data specifically. If you have other types of data that needs to be treated specially, you may need to alter the script to account for it.

## Usage

Let's assume that we have a table `MAS_STEP_STATUSES` that is a status lookup table with a structure like this:

```plaintext
Name            Null?    Type
--------------- -------- -------------------
ID              NOT NULL NUMBER
NAME            NOT NULL VARCHAR2(255 CHAR)
CODE            NOT NULL VARCHAR2(20 CHAR)
DESCRIPTION              VARCHAR2(4000 CHAR)
CREATED_BY      NOT NULL VARCHAR2(60)
CREATED_ON      NOT NULL DATE
LAST_UPDATED_BY          VARCHAR2(60)
LAST_UPDATED_ON          DATE
```

The CODE column is unique, immutable and is used in some PL/SQL routines to determine the status of some records. Therefore we would use that column as the unique identifier in any `MERGE` statement we might create.

The last four columns are the standard APEX Audit columns and we're not so interested in retaining those values.

All you have to do is change the 3 lines in the `DECLARE` section of the package

- `table_name` is the table you want to create the merge for
- `column_list` is the comma-separated list of columns you wish to extract data for

  - INCLUDE all the columns of interest
  - INCLUDE the column you wish to MATCH for the merge
  - EXCLUDE the ID and things like the APEX Audit Columns

- `match_columns` are the columns from the column list that should be used in the `MATCH` clause of the merge

So you're change the beginning of the procedure to look like this:

```sql
-->>>>>>>>>>>>>>>>>>>> CHANGE THE LINES BELOW <<<<<<<<<<<<<<<<<<<<<<<
   -- Table to merge in to (UPPER CASE)
   table_name    varchar2(30) := 'MAS_STEP_STATUSES';
   -- LIST OF COLUMNS IN THE TABLE TO INCLUDE
   --  Include columns used to match in the MERGE statement
   --  Exclude things like ID and APEX AUDIT COLS
   column_list   varchar2(4000) := 'name, code, description';
   -- Columns used for the MERGE MATHCH (comma separated list)
   match_columns varchar2(4000) := 'code';
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

If the data in our table looks like this:

```sql
SQL> select * from mas_step_statuses;

   ID NAME        CODE        DESCRIPTION    CREATED_BY     CREATED_ON    LAST_UPDATED_BY    LAST_UPDATED_ON
_____ ___________ ___________ ______________ ______________ _____________ __________________ __________________
    1 Pending     PENDING                    DGAULT         20-DEC-22
    2 Assinged    ASSINGED                   DGAULT         20-DEC-22
    3 Complete    COMPLETE                   DGAULT         20-DEC-22
```

This this would be the output of the script : A Merge script that contains the current data.

```sql
set define off;

PROMPT MAS_STEP_STATUSES data

declare
  l_json clob;
begin

  -- Load data in JSON object
  l_json := q'!
[
{
"NAME":"Pending"
,"CODE":"PENDING"
}
,{
"NAME":"Assinged"
,"CODE":"ASSINGED"
}
,{
"NAME":"Complete"
,"CODE":"COMPLETE"
}
]

!';

for data in (
  select *
  from json_table(l_json, '$[*]' columns
        NAME varchar2(255)  path '$.NAME'
      , CODE varchar2(20)  path '$.CODE'
      , DESCRIPTION varchar2(4000)  path '$.DESCRIPTION'

   )
) LOOP
   merge into MAS_STEP_STATUSES dest
      using (
         select
           data.code code
         from dual
      ) src
      on (1 = 1
          and dest.code = src.code
       )
   when matched then
      update
         set
          dest.name = data.name

   when not matched then
      insert (
          name

   )
   values (
          data.name
 );
end loop;

end;
/
```

To reinstantiate the data (or reset it to your _saved_ values) in any environment, just run the script.

I hope that someone besides me finds this useful.
