"! Off-stack stand-in for SAP's XCO_CP, used only by the abaplint transpiler: ZCL_ATK reads the
"! call stack through XCO (CL_ABAP_GET_CALL_STACK is not permitted in ABAP for Cloud Development)
"! and open-abap-core has no XCO. The stubs in this folder model just the shapes ATK uses:
"! xco_cp=>current->call_stack->full( )->as_text( format )->get_lines( )->value, which is empty
"! off-stack, so a call of a double has no origin there. Never imported by abapGit (its starting
"! folder is /src/), never seen by abaplint (XCO is outside its error namespace).
CLASS xco_cp DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA current TYPE REF TO cl_xco_cp_current READ-ONLY.

    CLASS-METHODS class_constructor.
ENDCLASS.


CLASS xco_cp IMPLEMENTATION.

  METHOD class_constructor.
    current = NEW #( ).
  ENDMETHOD.

ENDCLASS.
