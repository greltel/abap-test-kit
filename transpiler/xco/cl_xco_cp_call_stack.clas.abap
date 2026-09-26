"! Off-stack stand-in, see xco_cp.clas.abap: a call stack, written as text with a format.
CLASS cl_xco_cp_call_stack DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS as_text
      IMPORTING io_format      TYPE REF TO if_xco_cs_format
      RETURNING VALUE(ro_text) TYPE REF TO if_xco_text.
ENDCLASS.


CLASS cl_xco_cp_call_stack IMPLEMENTATION.

  METHOD as_text.
    ro_text = NEW cl_xco_text( ).
  ENDMETHOD.

ENDCLASS.
