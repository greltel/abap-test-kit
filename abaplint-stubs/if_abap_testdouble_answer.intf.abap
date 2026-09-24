INTERFACE if_abap_testdouble_answer PUBLIC.
  METHODS answer
    IMPORTING arguments     TYPE REF TO if_abap_testdouble_arguments
              double_handle TYPE REF TO if_abap_testdouble_handle
              method_name   TYPE abap_methname
    CHANGING  result        TYPE REF TO if_abap_testdouble_result
    RAISING   cx_atd_exception_core.
ENDINTERFACE.
