"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: check on the calls of a spy</p>
"! A check on the calls a spy recorded for one method. Every step checks on its own:
"! was_called( ) that there was a call, with( ) that a call had the arguments named so far,
"! times( ) that exactly that many calls matched.
INTERFACE zif_atk_call_verification PUBLIC.

  "! Counts only calls where this input parameter had this value, and fails the test at once
  "! unless at least one recorded call has this value and the values named before.
  "! The failure shows the closest actual call and the parameters that differ.
  "! Raises ZCX_ATK if the parameter is not an input or the value does not fit its type.
  "! @parameter parameter | IMPORTING or CHANGING parameter of the method
  "! @parameter value     | Expected value; converted to the parameter type, never with loss
  "! @parameter self      | This check, for chaining
  METHODS with
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_verification.

  "! Fails the test unless exactly this many matching calls were recorded.
  "! The failure shows the expected arguments and the matching calls.
  "! Raises ZCX_ATK if the number is below 1: for a method that must not be called, use
  "! was_not_called( ).
  "! @parameter expected_calls | Number of matching calls, at least 1
  METHODS times
    IMPORTING expected_calls TYPE i.

ENDINTERFACE.
