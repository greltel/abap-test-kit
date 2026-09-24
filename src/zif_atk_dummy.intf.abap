"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: dummy - must never be called</p>
"! A double that must never be called. Any call fails the test and names the method,
"! so you know you need a stub instead.
INTERFACE zif_atk_dummy PUBLIC.

  INTERFACES zif_atk_double.

  "! See {@link zif_atk_double.METH:instance}.
  ALIASES instance FOR zif_atk_double~instance.

ENDINTERFACE.
