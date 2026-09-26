"! Off-stack stand-in, see xco_cp.clas.abap: the formats and line number flavors of the call
"! stack text, xco_cp_call_stack=>format->adt( ) and xco_cp_call_stack=>line_number_flavor->include.
CLASS xco_cp_call_stack DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA format TYPE REF TO cl_xco_cp_cs_format_factory READ-ONLY.
    CLASS-DATA line_number_flavor TYPE REF TO cl_xco_cp_cs_lnf_factory READ-ONLY.

    CLASS-METHODS class_constructor.
ENDCLASS.


CLASS xco_cp_call_stack IMPLEMENTATION.

  METHOD class_constructor.
    format = NEW #( ).
    line_number_flavor = NEW #( ).
  ENDMETHOD.

ENDCLASS.
