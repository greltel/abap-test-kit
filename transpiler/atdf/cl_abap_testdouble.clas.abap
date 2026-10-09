"! Off-stack stand-in for SAP's CL_ABAP_TESTDOUBLE, used only by the abaplint transpiler.
"! The behaviour lives in atdf_runtime.mjs next to this file; the @KERNEL lines delegate to it.
"! transpiler/setup.mjs loads it into globalThis.atdfRuntime, so no path depends on the output layout.
"! Never imported by abapGit (its starting folder is /src/), never seen by abaplint
"! (abaplint.json reads /abaplint-stubs/ for the signature).
CLASS cl_abap_testdouble DEFINITION PUBLIC FINAL CREATE PRIVATE FOR TESTING.
  PUBLIC SECTION.
    TYPES ty_object_name TYPE c LENGTH 30.

    CLASS-METHODS configure_call
      IMPORTING double               TYPE REF TO object
      RETURNING VALUE(configuration) TYPE REF TO if_abap_testdouble_config.

    CLASS-METHODS create
      IMPORTING object_name   TYPE ty_object_name
                double_name   TYPE string OPTIONAL
      RETURNING VALUE(double) TYPE REF TO object.

    CLASS-METHODS verify_expectations
      IMPORTING double TYPE REF TO object.
ENDCLASS.


CLASS cl_abap_testdouble IMPLEMENTATION.

  METHOD create.
    WRITE '@KERNEL const atdf = globalThis.atdfRuntime;'.
    WRITE '@KERNEL $double.set(await atdf.create(object_name));'.
  ENDMETHOD.


  METHOD configure_call.
    WRITE '@KERNEL const atdf = globalThis.atdfRuntime;'.
    WRITE '@KERNEL configuration.set(await atdf.configureCall($double));'.
  ENDMETHOD.


  METHOD verify_expectations.
    WRITE '@KERNEL const atdf = globalThis.atdfRuntime;'.
    WRITE '@KERNEL await atdf.verifyExpectations($double);'.
  ENDMETHOD.

ENDCLASS.
