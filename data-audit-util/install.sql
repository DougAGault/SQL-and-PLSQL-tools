set feedback off

PRO Installing data-audit-util

PRO .. util_audit_control.pks
@util_audit_control.pks

PRO .. util_audit.pks
@util_audit.pks

PRO .. util_audit.pkb
@util_audit.pkb

PRO create audit table
exec util_audit.create_audit_table(p_action => 'EXECUTE');
PRO create lookups table
exec util_audit.create_audit_lookups_table(p_action => 'EXECUTE');


PRO Recompile code that is now aware that the audit table exists
PRO .. util_audit_control.pks
@util_audit_control.pks

PRO .. util_audit.pks
@util_audit.pks

PRO .. util_audit.pkb
@util_audit.pkb
