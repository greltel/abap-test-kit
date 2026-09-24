"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: one call a mock must receive</p>
"! One call a mock must receive: with which arguments, how often, and what the mock answers.
INTERFACE zif_atk_call_expectation PUBLIC.

  "! Expects this value for this input parameter. Parameters you do not name match any value.
  "! Raises ZCX_ATK if the parameter is not an input or the value does not fit its type.
  "! @parameter parameter | IMPORTING or CHANGING parameter of the method
  "! @parameter value     | Expected value; converted to the parameter type, never with loss
  "! @parameter self      | This expectation, for chaining
  METHODS with
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_expectation.

  "! Sets how many matching calls must happen. Without it: exactly one.
  "! Raises ZCX_ATK if the number is below 1.
  "! @parameter expected_calls | Number of calls, at least 1
  "! @parameter self           | This expectation, for chaining
  METHODS times
    IMPORTING expected_calls TYPE i
    RETURNING VALUE(self)    TYPE REF TO zif_atk_call_expectation.

  "! Sets the RETURNING value the code under test receives.
  "! Raises ZCX_ATK if the method has no RETURNING parameter or the value does not fit.
  "! @parameter value | Value of the method's RETURNING parameter type
  "! @parameter self  | This expectation, for chaining
  METHODS returns
    IMPORTING value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_expectation.

  "! Sets an EXPORTING or CHANGING parameter; you do not need to know which of the two it is.
  "! Raises ZCX_ATK if the parameter is not an output or the value does not fit its type.
  "! @parameter parameter | EXPORTING or CHANGING parameter of the method
  "! @parameter value     | Value handed back to the code under test
  "! @parameter self      | This expectation, for chaining
  METHODS sets
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_expectation.

  "! Makes the expected call raise this exception instead of returning. Ends the expectation.
  "! Raises ZCX_ATK if the method does not declare the exception.
  "! @parameter exception | An exception the method declares, or a CX_NO_CHECK one
  METHODS raises
    IMPORTING exception TYPE REF TO cx_root.

ENDINTERFACE.
