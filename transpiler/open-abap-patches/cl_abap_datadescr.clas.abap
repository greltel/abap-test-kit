CLASS cl_abap_datadescr DEFINITION PUBLIC INHERITING FROM cl_abap_typedescr.
  PUBLIC SECTION.
    CLASS-METHODS get_data_type_kind
      IMPORTING
        p_data             TYPE data
      RETURNING
        VALUE(p_type_kind) TYPE abap_typekind.

    METHODS applies_to_data
      IMPORTING
        p_data        TYPE data
      RETURNING
        VALUE(p_flag) TYPE abap_bool.

    "! Patch helper: does this description also describe the data OTHER describes?
    METHODS describes
      IMPORTING
        other         TYPE REF TO cl_abap_typedescr
      RETURNING
        VALUE(p_flag) TYPE abap_bool.
ENDCLASS.

CLASS cl_abap_datadescr IMPLEMENTATION.

  METHOD get_data_type_kind.
    DATA descr TYPE REF TO cl_abap_typedescr.
    descr = cl_abap_typedescr=>describe_by_data( p_data ).
    p_type_kind = descr->type_kind.
  ENDMETHOD.

  METHOD applies_to_data.
    " open-abap-core leaves this as a todo; this patch compares the type of P_DATA with
    " this description: same kind and technical type, and for structures and tables the
    " same components, recursively
    p_flag = describes( cl_abap_typedescr=>describe_by_data( p_data ) ).
  ENDMETHOD.

  METHOD describes.
    DATA lo_this_struct    TYPE REF TO cl_abap_structdescr.
    DATA lo_other_struct   TYPE REF TO cl_abap_structdescr.
    DATA lo_this_table     TYPE REF TO cl_abap_tabledescr.
    DATA lo_other_table    TYPE REF TO cl_abap_tabledescr.
    DATA lo_this_line      TYPE REF TO cl_abap_datadescr.
    DATA lo_other_line     TYPE REF TO cl_abap_datadescr.
    DATA lt_this_comps     TYPE cl_abap_structdescr=>component_table.
    DATA lt_other_comps    TYPE cl_abap_structdescr=>component_table.
    DATA ls_this_comp      LIKE LINE OF lt_this_comps.
    DATA ls_other_comp     LIKE LINE OF lt_other_comps.
    DATA lo_this_comp_type TYPE REF TO cl_abap_datadescr.
    DATA lv_index          TYPE i.

    p_flag = abap_false.
    IF other IS NOT BOUND.
      RETURN.
    ENDIF.
    IF other->kind <> kind OR other->type_kind <> type_kind.
      RETURN.
    ENDIF.

    CASE kind.
      WHEN kind_elem.
        p_flag = xsdbool( other->length = length AND other->decimals = decimals ).
      WHEN kind_struct.
        lo_this_struct ?= me.
        lo_other_struct ?= other.
        lt_this_comps = lo_this_struct->get_components( ).
        lt_other_comps = lo_other_struct->get_components( ).
        IF lines( lt_this_comps ) <> lines( lt_other_comps ).
          RETURN.
        ENDIF.
        LOOP AT lt_this_comps INTO ls_this_comp.
          lv_index = sy-tabix.
          READ TABLE lt_other_comps INDEX lv_index INTO ls_other_comp.
          IF ls_this_comp-name <> ls_other_comp-name.
            RETURN.
          ENDIF.
          lo_this_comp_type = ls_this_comp-type.
          IF lo_this_comp_type->describes( ls_other_comp-type ) = abap_false.
            RETURN.
          ENDIF.
        ENDLOOP.
        p_flag = abap_true.
      WHEN kind_table.
        lo_this_table ?= me.
        lo_other_table ?= other.
        lo_this_line = lo_this_table->get_table_line_type( ).
        lo_other_line = lo_other_table->get_table_line_type( ).
        p_flag = lo_this_line->describes( lo_other_line ).
      WHEN OTHERS.
        p_flag = xsdbool( other->absolute_name = absolute_name ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.