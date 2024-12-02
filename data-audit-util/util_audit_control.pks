------------------------------------------------------------------------------
-- DESCRIPTION 
--   This code creates a "util_audit_control" package of the following form:
-- 
--   create or replace package util_audit_control as
--     is_installed  constant boolean := true;
--   end is_installed;
--   /
-- 
-- NOTES 
-- * Notice that this package does NOT require a body, and that's valid.
-- 
-- * This package can then be used during conditional compilation for objects
-- * that are yet to be installed
-- * For example:
-- 
--   $if util_audit_control.is_installed $then
--     delete from util_audit_records WHERE table_name = v_table_name;
--   $else
--     null;
--   $end
-- 
------------------------------------------------------------------------------

declare
l_audit_exists varchar2(5);
begin
select case when n = 0 then 'false' else 'true' end
  into l_audit_exists
from (
    select count(*) n from user_tables where table_name = 'UTIL_AUDIT_RECORDS'
);
execute immediate '
create or replace package util_audit_control as
  is_installed  constant boolean := ' || l_audit_exists || ';
end util_audit_control;
';
end;
/
