"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: mock - strict, declared calls</p>
"! A strict double: declare every expected call before the act step. Any other call fails
"! the test at once; verify( ) reports declared calls that did not happen as often as declared.
INTERFACE zif_atk_mock PUBLIC.

  INTERFACES zif_atk_double.

  "! See {@link zif_atk_double.METH:instance}.
  ALIASES instance FOR zif_atk_double~instance.

  "! Declares a call the code under test must make. Without times( ) it must happen once.
  "! Raises ZCX_ATK if the method does not exist or cannot be doubled.
  "! @parameter method_name | Method as declared in the doubled type
  "! @parameter result      | The expectation, to narrow and complete
  METHODS expect_call
    IMPORTING method_name   TYPE csequence
    RETURNING VALUE(result) TYPE REF TO zif_atk_call_expectation.

  "! Checks that every declared call happened as often as declared. Call me in the
  "! assert step: a mock that is never verified checks nothing.
  METHODS verify.

ENDINTERFACE.
