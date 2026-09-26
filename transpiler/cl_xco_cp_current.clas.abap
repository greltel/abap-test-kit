"! Off-stack stand-in, see xco_cp.clas.abap: what xco_cp=>current returns.
CLASS cl_xco_cp_current DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA call_stack TYPE REF TO cl_xco_cp_call_stack_source READ-ONLY.

    METHODS constructor.
ENDCLASS.


CLASS cl_xco_cp_current IMPLEMENTATION.

  METHOD constructor.
    call_stack = NEW #( ).
  ENDMETHOD.

ENDCLASS.
