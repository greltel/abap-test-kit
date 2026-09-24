"! <p class="shorttext synchronized" lang="EN">ATK test fixture: final class</p>
"! Fixture for the tests of the ABAP Test Kit: a final class, which no double can extend.
CLASS zcl_atk_test_sealed DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns the name unchanged.
    "! @parameter name   | Who to greet
    "! @parameter result | The greeting
    METHODS greet
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_atk_test_sealed IMPLEMENTATION.

  METHOD greet.
    result = name.
  ENDMETHOD.

ENDCLASS.
