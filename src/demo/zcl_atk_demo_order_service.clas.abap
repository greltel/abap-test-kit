"! <p class="shorttext synchronized" lang="EN">ATK demo: cancels orders</p>
"! Demo code under test for the ABAP Test Kit examples. Its collaborators are injected through
"! the constructor, which is what makes it testable with test doubles.
CLASS zcl_atk_demo_order_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_atk_demo_order_service.

    "! @parameter repository | Where orders are read
    "! @parameter audit_log  | Where cancellations are recorded
    METHODS constructor
      IMPORTING repository TYPE REF TO zif_atk_demo_order_repo
                audit_log  TYPE REF TO zif_atk_demo_audit_log.

  PRIVATE SECTION.
    DATA repository TYPE REF TO zif_atk_demo_order_repo.
    DATA audit_log TYPE REF TO zif_atk_demo_audit_log.

ENDCLASS.


CLASS zcl_atk_demo_order_service IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
    me->audit_log = audit_log.
  ENDMETHOD.


  METHOD zif_atk_demo_order_service~cancel.
    DATA(order) = repository->get_order( order_id ).
    IF order-status = zif_atk_demo_order_repo=>status-cancelled.
      RETURN.
    ENDIF.
    audit_log->write( order_id = order_id
                      action   = zif_atk_demo_audit_log=>action-cancelled ).
  ENDMETHOD.


  METHOD zif_atk_demo_order_service~is_cancelled.
    DATA(order) = repository->get_order( order_id ).
    result = xsdbool( order-status = zif_atk_demo_order_repo=>status-cancelled ).
  ENDMETHOD.

ENDCLASS.
