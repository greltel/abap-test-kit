"! <p class="shorttext synchronized" lang="EN">ATK demo: order not found</p>
"! Demo exception for the ABAP Test Kit examples: no order has the requested number.
CLASS zcx_atk_demo_not_found DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter previous | The exception that caused this one, if any
    METHODS constructor
      IMPORTING previous TYPE REF TO cx_root OPTIONAL.

ENDCLASS.


CLASS zcx_atk_demo_not_found IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
  ENDMETHOD.

ENDCLASS.
