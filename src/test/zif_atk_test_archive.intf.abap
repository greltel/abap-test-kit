"! <p class="shorttext synchronized" lang="EN">ATK test fixture: interface with a component</p>
"! Fixture for the tests of the ABAP Test Kit: an interface that includes another interface,
"! so that the methods of the component can be doubled through it.
INTERFACE zif_atk_test_archive PUBLIC.

  INTERFACES zif_atk_test_audit_log.

  "! The archive's own method, next to the ones of the component interface.
  "! @parameter result | Number of purged entries
  METHODS purge
    RETURNING VALUE(result) TYPE i.

ENDINTERFACE.
