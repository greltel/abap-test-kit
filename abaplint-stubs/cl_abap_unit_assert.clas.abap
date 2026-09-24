CLASS cl_abap_unit_assert DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS fail
      IMPORTING msg    TYPE csequence OPTIONAL
                level  TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit   TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
                detail TYPE csequence OPTIONAL
      PREFERRED PARAMETER msg.
    CLASS-METHODS assert_equals
      IMPORTING act                     TYPE any
                exp                     TYPE any
                ignore_hash_sequence    TYPE abap_bool DEFAULT abap_false
                tol                     TYPE f OPTIONAL
                msg                     TYPE csequence OPTIONAL
                level                   TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit                    TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
    CLASS-METHODS assert_bound
      IMPORTING act                     TYPE any
                msg                     TYPE csequence OPTIONAL
                level                   TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit                    TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
    CLASS-METHODS assert_not_bound
      IMPORTING act                     TYPE any
                msg                     TYPE csequence OPTIONAL
                level                   TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit                    TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
    CLASS-METHODS assert_initial
      IMPORTING act                     TYPE any DEFAULT sy-subrc
                msg                     TYPE csequence OPTIONAL
                level                   TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit                    TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
    CLASS-METHODS assert_true
      IMPORTING act                     TYPE abap_bool
                msg                     TYPE csequence OPTIONAL
                level                   TYPE int1 DEFAULT if_abap_unit_constant=>severity-high
                quit                    TYPE int1 DEFAULT if_abap_unit_constant=>quit-test
      RETURNING VALUE(assertion_failed) TYPE abap_bool.
ENDCLASS.
CLASS cl_abap_unit_assert IMPLEMENTATION.
  METHOD fail.
  ENDMETHOD.
  METHOD assert_equals.
  ENDMETHOD.
  METHOD assert_bound.
  ENDMETHOD.
  METHOD assert_not_bound.
  ENDMETHOD.
  METHOD assert_initial.
  ENDMETHOD.
  METHOD assert_true.
  ENDMETHOD.
ENDCLASS.
