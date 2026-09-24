"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: stub - answers calls as told</p>
"! A double that answers calls the way your test tells it to. Once a method has rules, a call
"! that matches none of them fails the test, so a typo in a value cannot pass unnoticed.
"! Methods without any rule return initial values.
INTERFACE zif_atk_stub PUBLIC.

  INTERFACES zif_atk_double.

  "! See {@link zif_atk_double.METH:instance}.
  ALIASES instance FOR zif_atk_double~instance.

  "! Starts a rule for one method: what the double answers when the code under test calls it.
  "! Complete the rule with returns( ), sets( ) or raises( ). When several rules match a call,
  "! the one with the most with( ) conditions wins; on a tie, the rule written last wins.
  "! Raises ZCX_ATK if the method does not exist or cannot be doubled.
  "! @parameter method_name | Method as declared in the doubled type, for example 'GET_ORDER'
  "! @parameter result      | The rule, to narrow with with( ) and complete
  METHODS when
    IMPORTING method_name   TYPE csequence
    RETURNING VALUE(result) TYPE REF TO zif_atk_call_rule.

ENDINTERFACE.
