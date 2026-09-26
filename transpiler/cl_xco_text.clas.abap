"! Off-stack stand-in, see xco_cp.clas.abap: the text of the call stack, empty off-stack.
CLASS cl_xco_text DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_xco_text.
ENDCLASS.


CLASS cl_xco_text IMPLEMENTATION.

  METHOD if_xco_text~get_lines.
    ro_lines = NEW cl_xco_string_table( ).
  ENDMETHOD.

ENDCLASS.
