INTERFACE if_abap_testdouble_arguments PUBLIC.
  METHODS get_param_changing
    IMPORTING name         TYPE abap_parmname
    RETURNING VALUE(value) TYPE REF TO data
    RAISING   cx_atd_exception_core.
  METHODS get_param_importing
    IMPORTING name         TYPE abap_parmname
    RETURNING VALUE(value) TYPE REF TO data
    RAISING   cx_atd_exception_core.
  METHODS has_next_parameter
    RETURNING VALUE(result) TYPE abap_bool.
  METHODS is_changing_param_supplied
    IMPORTING name          TYPE abap_parmname
    RETURNING VALUE(result) TYPE abap_bool
    RAISING   cx_atd_exception_core.
  METHODS is_importing_param_supplied
    IMPORTING name          TYPE abap_parmname
    RETURNING VALUE(result) TYPE abap_bool
    RAISING   cx_atd_exception_core.
  METHODS next_parameter
    EXPORTING ignore TYPE abap_bool
              kind   TYPE abap_parmkind
              name   TYPE abap_parmname
    RAISING   cx_atd_exception_core.
  METHODS reset_iterator.
  METHODS size_of
    RETURNING VALUE(size) TYPE i.
ENDINTERFACE.
