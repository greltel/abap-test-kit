"! <p class="shorttext synchronized" lang="EN">ATK test fixture: audit log</p>
"! Fixture for the tests of the ABAP Test Kit: a command-style collaborator without outputs,
"! the typical target of a spy or mock.
INTERFACE zif_atk_test_audit_log PUBLIC.

  "! Writes one entry.
  "! @parameter order_id | Order the entry is about
  "! @parameter action   | What happened to the order
  METHODS write
    IMPORTING order_id TYPE zif_atk_test_orders=>ty_order_id
              action   TYPE string.

ENDINTERFACE.
