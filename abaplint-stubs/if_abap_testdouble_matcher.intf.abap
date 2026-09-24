INTERFACE if_abap_testdouble_matcher PUBLIC.
  METHODS matches
    IMPORTING actual_arguments     TYPE REF TO if_abap_testdouble_arguments
              configured_arguments TYPE REF TO if_abap_testdouble_arguments
              method_name          TYPE abap_methname
    RETURNING VALUE(result)        TYPE abap_bool.
ENDINTERFACE.
