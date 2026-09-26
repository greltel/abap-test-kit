"! Off-stack stand-in, see xco_cp.clas.abap: xco_cp_call_stack=>format.
CLASS cl_xco_cp_cs_format_factory DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS adt
      RETURNING VALUE(ro_format) TYPE REF TO cl_xco_cp_cs_fmt_adt.
ENDCLASS.


CLASS cl_xco_cp_cs_format_factory IMPLEMENTATION.

  METHOD adt.
    ro_format = NEW #( ).
  ENDMETHOD.

ENDCLASS.
