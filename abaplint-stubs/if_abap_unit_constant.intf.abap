INTERFACE if_abap_unit_constant PUBLIC.
  CONSTANTS:
    BEGIN OF quit,
      no      TYPE int1 VALUE 0,
      test    TYPE int1 VALUE 1,
      class   TYPE int1 VALUE 2,
      program TYPE int1 VALUE 3,
    END OF quit.
  CONSTANTS:
    BEGIN OF severity,
      low    TYPE int1 VALUE 0,
      medium TYPE int1 VALUE 1,
      high   TYPE int1 VALUE 2,
    END OF severity.
ENDINTERFACE.
