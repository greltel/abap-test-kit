"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: one answer of a stub or spy</p>
"! One answer of a stub or spy: which calls it applies to and what the double does then.
INTERFACE zif_atk_call_rule PUBLIC.

  "! Applies the rule only when this input parameter has this value.
  "! Parameters you do not name match any value. Call it once per parameter.
  "! Raises ZCX_ATK if the parameter is not an input or the value does not fit its type.
  "! @parameter parameter | IMPORTING or CHANGING parameter of the method, for example 'ORDER_ID'
  "! @parameter value     | Expected value; converted to the parameter type, never with loss
  "! @parameter self      | This rule, for chaining
  METHODS with
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_rule.

  "! Sets the RETURNING value the code under test receives.
  "! Raises ZCX_ATK if the method has no RETURNING parameter or the value does not fit.
  "! @parameter value | Value of the method's RETURNING parameter type
  "! @parameter self  | This rule, for chaining
  METHODS returns
    IMPORTING value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_rule.

  "! Sets an EXPORTING or CHANGING parameter; you do not need to know which of the two it is.
  "! Raises ZCX_ATK if the parameter is not an output or the value does not fit its type.
  "! @parameter parameter | EXPORTING or CHANGING parameter of the method, for example 'MESSAGES'
  "! @parameter value     | Value handed back to the code under test
  "! @parameter self      | This rule, for chaining
  METHODS sets
    IMPORTING parameter   TYPE csequence
              value       TYPE any
    RETURNING VALUE(self) TYPE REF TO zif_atk_call_rule.

  "! Makes the call raise this exception instead of returning. Ends the rule.
  "! Raises ZCX_ATK if the method does not declare the exception.
  "! @parameter exception | An exception the method declares, or a CX_NO_CHECK one
  METHODS raises
    IMPORTING exception TYPE REF TO cx_root.

ENDINTERFACE.
