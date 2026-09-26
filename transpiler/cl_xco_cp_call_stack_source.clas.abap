"! Off-stack stand-in, see xco_cp.clas.abap: xco_cp=>current->call_stack, which hands out the
"! full call stack. Off-stack there is none.
CLASS cl_xco_cp_call_stack_source DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS full
      RETURNING VALUE(ro_call_stack) TYPE REF TO cl_xco_cp_call_stack.
ENDCLASS.


CLASS cl_xco_cp_call_stack_source IMPLEMENTATION.

  METHOD full.
    ro_call_stack = NEW #( ).
  ENDMETHOD.

ENDCLASS.
