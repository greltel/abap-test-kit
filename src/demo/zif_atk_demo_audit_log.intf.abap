"! <p class="shorttext synchronized" lang="EN">ATK demo: records what happened to orders</p>
"! Demo collaborator for the ABAP Test Kit examples: where the order service records actions.
INTERFACE zif_atk_demo_audit_log PUBLIC.

  CONSTANTS:
    "! Actions the order service records
    BEGIN OF action,
      cancelled TYPE string VALUE `CANCELLED`,
    END OF action.

  "! Records one action.
  "! @parameter order_id | Order the action is about
  "! @parameter action   | What happened, one of {@link zif_atk_demo_audit_log.DATA:action}
  METHODS write
    IMPORTING order_id TYPE zif_atk_demo_order_repo=>ty_order_id
              action   TYPE string.

ENDINTERFACE.
