"! Off-stack stand-in, see xco_cp.clas.abap: a text of several lines.
INTERFACE if_xco_text PUBLIC.
  METHODS get_lines
    RETURNING VALUE(ro_lines) TYPE REF TO if_xco_string_table.
ENDINTERFACE.
