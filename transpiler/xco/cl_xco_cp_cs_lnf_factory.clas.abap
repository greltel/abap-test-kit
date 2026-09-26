"! Off-stack stand-in, see xco_cp.clas.abap: xco_cp_call_stack=>line_number_flavor.
CLASS cl_xco_cp_cs_lnf_factory DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA include TYPE REF TO if_xco_cs_line_number_flavor READ-ONLY.
    DATA source TYPE REF TO if_xco_cs_line_number_flavor READ-ONLY.

    METHODS constructor.
ENDCLASS.


CLASS cl_xco_cp_cs_lnf_factory IMPLEMENTATION.

  METHOD constructor.
    include = NEW cl_xco_cp_cs_line_number_flavor( ).
    source = NEW cl_xco_cp_cs_line_number_flavor( ).
  ENDMETHOD.

ENDCLASS.
