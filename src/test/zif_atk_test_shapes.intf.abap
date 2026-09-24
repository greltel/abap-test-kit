"! <p class="shorttext synchronized" lang="EN">ATK test fixture: parameter shapes</p>
"! Fixture for the tests of the ABAP Test Kit: one method per parameter shape a double must
"! handle. The EXPORTING and CHANGING parameters are deliberate - they are what is being tested.
INTERFACE zif_atk_test_shapes PUBLIC.

  "! Country code with a fixed length, to test values that are too long
  TYPES ty_country_code TYPE c LENGTH 3.
  "! Amount with two decimals, to test values that would be rounded
  TYPES ty_amount TYPE p LENGTH 8 DECIMALS 2.
  "! Names with a key, to test tables whose type differs only in the key
  TYPES ty_names TYPE STANDARD TABLE OF string WITH NON-UNIQUE KEY table_line.

  "! EXPORTING parameters.
  "! @parameter full_name  | Name to split
  "! @parameter first_name | First part
  "! @parameter last_name  | Last part
  METHODS split_name
    IMPORTING full_name  TYPE string
    EXPORTING first_name TYPE string
              last_name  TYPE string.

  "! A mandatory CHANGING parameter.
  "! @parameter text | Text to normalize in place
  METHODS normalize
    CHANGING text TYPE string.

  "! A generically typed input.
  "! @parameter anything | Any value
  "! @parameter result   | Description of the value
  METHODS describe
    IMPORTING anything      TYPE any
    RETURNING VALUE(result) TYPE string.

  "! A generically typed table input.
  "! @parameter rows   | Any index table
  "! @parameter result | Number of rows
  METHODS count_rows
    IMPORTING rows          TYPE INDEX TABLE
    RETURNING VALUE(result) TYPE i.

  "! An input with a fixed length.
  "! @parameter code   | Country code
  "! @parameter result | Country name
  METHODS country_name
    IMPORTING code          TYPE ty_country_code
    RETURNING VALUE(result) TYPE string.

  "! An input with decimals.
  "! @parameter amount | Amount to book
  METHODS book
    IMPORTING amount TYPE ty_amount.

  "! A table input with a key.
  "! @parameter names  | Names to join
  "! @parameter result | The joined names
  METHODS join_names
    IMPORTING names         TYPE ty_names
    RETURNING VALUE(result) TYPE string.

  "! A returned object reference.
  "! @parameter result | A new audit log
  METHODS new_log
    RETURNING VALUE(result) TYPE REF TO zif_atk_test_audit_log.

ENDINTERFACE.
