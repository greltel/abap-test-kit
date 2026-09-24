"! <p class="shorttext synchronized" lang="EN">ATK test fixture: order repository</p>
"! Fixture for the tests of the ABAP Test Kit: a collaborator with RETURNING values, a numeric
"! text key to test conversions from literals, and a declared exception.
INTERFACE zif_atk_test_orders PUBLIC.

  "! Order number
  TYPES ty_order_id TYPE n LENGTH 10.

  TYPES:
    "! One order
    BEGIN OF ty_order,
      id       TYPE ty_order_id,
      customer TYPE string,
      amount   TYPE decfloat34,
    END OF ty_order.

  "! Reads one order.
  "! @parameter order_id              | Order to read
  "! @parameter result                | The order
  "! @raising   zcx_atk_test_not_found | No order has this number
  METHODS get_order
    IMPORTING order_id      TYPE ty_order_id
    RETURNING VALUE(result) TYPE ty_order
    RAISING   zcx_atk_test_not_found.

  "! Counts the open orders.
  "! @parameter result | Number of open orders
  METHODS count_open
    RETURNING VALUE(result) TYPE i.

ENDINTERFACE.
