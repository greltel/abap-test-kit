"! <p class="shorttext synchronized" lang="EN">ATK test fixture: non-final class</p>
"! Fixture for the tests of the ABAP Test Kit: a class that is deliberately not final and has
"! no interface. The test double framework could double it, but ATK must reject it, because ATK
"! doubles interfaces only.
CLASS zcl_atk_test_extensible DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns the name unchanged.
    "! @parameter name   | Who to greet
    "! @parameter result | The greeting
    METHODS greet
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_atk_test_extensible IMPLEMENTATION.

  METHOD greet.
    result = name.
  ENDMETHOD.

ENDCLASS.

