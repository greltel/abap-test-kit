"! Off-stack stand-in, see xco_cp.clas.abap: the ADT format of the call stack text.
CLASS cl_xco_cp_cs_fmt_adt DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_xco_cs_format.

    METHODS with_line_number_flavor
      IMPORTING io_line_number_flavor TYPE REF TO if_xco_cs_line_number_flavor
      RETURNING VALUE(ro_me)          TYPE REF TO cl_xco_cp_cs_fmt_adt.
ENDCLASS.


CLASS cl_xco_cp_cs_fmt_adt IMPLEMENTATION.

  METHOD with_line_number_flavor.
    ro_me = me.
  ENDMETHOD.

ENDCLASS.
