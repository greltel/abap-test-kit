"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: check on the calls of a spy</p>
"! A check on the calls a spy recorded for one method.
INTERFACE zif_atk_call_verification PUBLIC.

  "! Counts only calls where this input parameter had this value.
  "! Raises ZCX_ATK if the parameter is not an input or the value does not fit its type.
  "! @parameter parameter | IMPORTING or CHANGING parameter of the method
  "! @parameter value     | Expected value; converted to the parameter type, never with loss
  "! @parameter self      | This check, for chaining
  METHODS with
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_verification.

  "! Fails the test unless exactly this many matching calls were recorded.
  "! The failure shows the expected arguments and the closest actual call.
  "! Raises ZCX_ATK if the number is negative.
  "! @parameter expected_calls | Number of matching calls; 0 means none
  METHODS times
    IMPORTING expected_calls TYPE i.

ENDINTERFACE.
