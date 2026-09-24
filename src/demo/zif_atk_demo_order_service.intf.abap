"! <p class="shorttext synchronized" lang="EN">ATK demo: cancels orders</p>
"! Demo code under test for the ABAP Test Kit examples.
INTERFACE zif_atk_demo_order_service PUBLIC.

  "! Cancels an open order and records the cancellation in the audit log.
  "! An order that is already cancelled stays as it is and is not recorded again.
  "! @parameter order_id              | Order to cancel
  "! @raising   zcx_atk_demo_not_found | No order has this number
  METHODS cancel
    IMPORTING order_id TYPE zif_atk_demo_order_repo=>ty_order_id
    RAISING   zcx_atk_demo_not_found.

  "! Tells whether an order is cancelled.
  "! @parameter order_id              | Order to check
  "! @parameter result                | abap_true if the order is cancelled
  "! @raising   zcx_atk_demo_not_found | No order has this number
  METHODS is_cancelled
    IMPORTING order_id      TYPE zif_atk_demo_order_repo=>ty_order_id
    RETURNING VALUE(result) TYPE abap_bool
    RAISING   zcx_atk_demo_not_found.

ENDINTERFACE.
