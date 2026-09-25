CLASS cl_abap_classdescr DEFINITION PUBLIC INHERITING FROM cl_abap_objectdescr.
  PUBLIC SECTION.

    DATA class_kind TYPE string.
    DATA create_visibility TYPE string.

    CLASS-METHODS get_class_name
      IMPORTING
        p_object      TYPE REF TO object
      RETURNING
        VALUE(p_name) TYPE abap_abstypename.

    METHODS get_super_class_type
      RETURNING
        VALUE(p_descr_ref) TYPE REF TO cl_abap_classdescr
      EXCEPTIONS
        super_class_not_found.

ENDCLASS.

CLASS cl_abap_classdescr IMPLEMENTATION.

  METHOD get_class_name.
    DATA lv_name TYPE string.
    WRITE '@KERNEL lv_name.set(p_object.get().constructor.INTERNAL_NAME);'.
    p_name = kernel_internal_name=>internal_to_rtti( lv_name ).
  ENDMETHOD.

  METHOD get_super_class_type.
    " open-abap-core leaves this as a todo; this patch walks STATIC_SUPER of the JS class
    DATA lv_internal TYPE string.
    DATA lv_any      TYPE string.
    DATA lv_found    TYPE abap_bool.

    lv_internal = kernel_internal_name=>rtti_to_internal( CONV string( absolute_name ) ).
    WRITE '@KERNEL const clas = abap.Classes[lv_internal.get()];'.
    WRITE '@KERNEL lv_any = clas?.STATIC_SUPER;'.
    WRITE '@KERNEL lv_found.set(lv_any === undefined ? "" : "X");'.
    IF lv_found = abap_false.
      RAISE super_class_not_found.
    ENDIF.
    p_descr_ref ?= cl_abap_classdescr=>_construct( lv_any ).
    p_descr_ref->type_kind = typekind_class.
    p_descr_ref->kind = kind_class.
    WRITE '@KERNEL lv_internal.set(lv_any.name.toUpperCase());'.
    p_descr_ref->relative_name = lv_internal.
    WRITE '@KERNEL lv_internal.set(lv_any.INTERNAL_NAME);'.
    p_descr_ref->absolute_name = kernel_internal_name=>internal_to_rtti( lv_internal ).
  ENDMETHOD.
ENDCLASS.
