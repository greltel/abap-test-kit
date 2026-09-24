"! <p class="shorttext synchronized" lang="EN">ATK test fixture: order not found</p>
"! Fixture for the tests of the ABAP Test Kit: a checked exception a doubled method declares.
CLASS zcx_atk_test_not_found DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter previous | The exception that caused this one, if any
    METHODS constructor
      IMPORTING previous TYPE REF TO cx_root OPTIONAL.

ENDCLASS.


CLASS zcx_atk_test_not_found IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
  ENDMETHOD.

ENDCLASS.
