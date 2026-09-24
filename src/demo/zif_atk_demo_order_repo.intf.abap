"! <p class="shorttext synchronized" lang="EN">ATK demo: reads orders</p>
"! Demo collaborator for the ABAP Test Kit examples: where the order service reads orders.
INTERFACE zif_atk_demo_order_repo PUBLIC.

  "! Order number
  TYPES ty_order_id TYPE n LENGTH 10.
  "! Order status, one of the values in {@link zif_atk_demo_order_repo.DATA:status}
  TYPES ty_status_code TYPE c LENGTH 1.

  TYPES:
    "! One order
    BEGIN OF ty_order,
      id     TYPE ty_order_id,
      status TYPE ty_status_code,
    END OF ty_order.

  CONSTANTS:
    "! Values of the order status
    BEGIN OF status,
      open      TYPE ty_status_code VALUE 'O',
      cancelled TYPE ty_status_code VALUE 'C',
    END OF status.

  "! Reads one order.
  "! @parameter order_id              | Order to read
  "! @parameter result                | The order
  "! @raising   zcx_atk_demo_not_found | No order has this number
  METHODS get_order
    IMPORTING order_id      TYPE ty_order_id
    RETURNING VALUE(result) TYPE ty_order
    RAISING   zcx_atk_demo_not_found.

ENDINTERFACE.
