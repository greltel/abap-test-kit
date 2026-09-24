"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: spy - stub that remembers calls</p>
"! A stub that also remembers every call, so the test can check the calls after the act step.
INTERFACE zif_atk_spy PUBLIC.

  INTERFACES zif_atk_stub.

  "! See {@link zif_atk_double.METH:instance}.
  ALIASES instance FOR zif_atk_double~instance.
  "! See {@link zif_atk_stub.METH:when}.
  ALIASES when FOR zif_atk_stub~when.

  "! Starts a check on the calls the code under test made to one method.
  "! Narrow it with with( ) and finish it with times( ) - without times( ) nothing is checked.
  "! Raises ZCX_ATK if the method does not exist or cannot be doubled.
  "! @parameter method_name | Method as declared in the doubled type, for example 'WRITE'
  "! @parameter result      | The check to complete
  METHODS was_called
    IMPORTING method_name   TYPE csequence
    RETURNING VALUE(result) TYPE REF TO zif_atk_call_verification.

  "! Fails the test if the code under test called this method at all.
  "! Raises ZCX_ATK if the method does not exist or cannot be doubled.
  "! @parameter method_name | Method as declared in the doubled type
  METHODS was_not_called
    IMPORTING method_name TYPE csequence.

ENDINTERFACE.
