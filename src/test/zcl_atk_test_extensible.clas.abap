"! <p class="shorttext synchronized" lang="EN">ATK test fixture: non-final class</p>
"! Fixture for the tests of the ABAP Test Kit: a class that is deliberately not final and has
"! no interface, so that doubling a class (not an interface) can be tested.
CLASS zcl_atk_test_extensible DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns the name unchanged; the tests replace this behavior with a double.
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
