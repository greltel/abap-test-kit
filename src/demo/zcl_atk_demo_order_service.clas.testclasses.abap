"! Object mother: the orders both test classes use, so that before and after compare fairly.
CLASS lth_orders DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS open_order
      RETURNING VALUE(result) TYPE zif_atk_demo_order_repo=>ty_order.

    CLASS-METHODS cancelled_order
      RETURNING VALUE(result) TYPE zif_atk_demo_order_repo=>ty_order.
ENDCLASS.


CLASS lth_orders IMPLEMENTATION.

  METHOD open_order.
    result = VALUE #( id     = '0000004711'
                      status = zif_atk_demo_order_repo=>status-open ).
  ENDMETHOD.


  METHOD cancelled_order.
    result = VALUE #( id     = '0000004711'
                      status = zif_atk_demo_order_repo=>status-cancelled ).
  ENDMETHOD.

ENDCLASS.


"! BEFORE: the scenarios with the classic ABAP Test Double Framework (CL_ABAP_TESTDOUBLE).
"! Every configuration takes two statements, and the second one looks like a real call.
CLASS ltc_with_raw_atdf DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA repository TYPE REF TO zif_atk_demo_order_repo.
    DATA audit_log TYPE REF TO zif_atk_demo_audit_log.
    DATA cut TYPE REF TO zif_atk_demo_order_service.

    METHODS setup.
    METHODS given_cancelled_then_true FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_order_then_raise FOR TESTING RAISING cx_static_check.
    METHODS when_cancel_then_logged_once FOR TESTING RAISING cx_static_check.
    METHODS given_cancelled_then_no_log FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_with_raw_atdf IMPLEMENTATION.

  METHOD setup.
    repository = CAST zif_atk_demo_order_repo( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_ORDER_REPO' ) ).
    audit_log = CAST zif_atk_demo_audit_log( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_AUDIT_LOG' ) ).
    cut = NEW zcl_atk_demo_order_service( repository = repository
                                          audit_log  = audit_log ).
  ENDMETHOD.


  METHOD given_cancelled_then_true.
    cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>cancelled_order( ) ).
    repository->get_order( '4711' ).

    DATA(is_cancelled) = cut->is_cancelled( '4711' ).

    cl_abap_unit_assert=>assert_true( act = is_cancelled msg = `A cancelled order must be reported as cancelled` ).
  ENDMETHOD.


  METHOD given_unknown_order_then_raise.
    DATA(was_raised) = abap_false.
    cl_abap_testdouble=>configure_call( repository )->raise_exception( NEW zcx_atk_demo_not_found( ) ).
    repository->get_order( '4711' ).

    TRY.
        cut->cancel( '4711' ).
      CATCH zcx_atk_demo_not_found.
        was_raised = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true( act = was_raised msg = `An unknown order must raise ZCX_ATK_DEMO_NOT_FOUND` ).
  ENDMETHOD.


  METHOD when_cancel_then_logged_once.
    cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>open_order( ) ).
    repository->get_order( '4711' ).
    cl_abap_testdouble=>configure_call( audit_log )->and_expect( )->is_called_times( 1 ).
    audit_log->write( order_id = '4711'
                      action   = zif_atk_demo_audit_log=>action-cancelled ).

    cut->cancel( '4711' ).

    cl_abap_testdouble=>verify_expectations( audit_log ).
  ENDMETHOD.


  METHOD given_cancelled_then_no_log.
    cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>cancelled_order( ) ).
    repository->get_order( '4711' ).
    cl_abap_testdouble=>configure_call( audit_log )->ignore_all_parameters( )->and_expect( )->is_never_called( ).
    audit_log->write( order_id = '4711'
                      action   = `` ).

    cut->cancel( '4711' ).

    cl_abap_testdouble=>verify_expectations( audit_log ).
  ENDMETHOD.

ENDCLASS.


"! AFTER: the same scenarios with the ABAP Test Kit - one sentence per configuration or check.
CLASS ltc_with_atk DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA repository TYPE REF TO zif_atk_stub.
    DATA audit_log TYPE REF TO zif_atk_spy.
    DATA cut TYPE REF TO zif_atk_demo_order_service.

    METHODS setup.
    METHODS given_cancelled_then_true FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_order_then_raise FOR TESTING.
    METHODS when_cancel_then_logged_once FOR TESTING RAISING cx_static_check.
    METHODS given_cancelled_then_no_log FOR TESTING RAISING cx_static_check.
    METHODS when_cancel_then_mock_verified FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_with_atk IMPLEMENTATION.

  METHOD setup.
    repository = zcl_atk=>stub( 'ZIF_ATK_DEMO_ORDER_REPO' ).
    audit_log = zcl_atk=>spy( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
    cut = NEW zcl_atk_demo_order_service( repository = CAST #( repository->instance( ) )
                                          audit_log  = CAST #( audit_log->instance( ) ) ).
  ENDMETHOD.


  METHOD given_cancelled_then_true.
    repository->when( 'GET_ORDER'
      )->with( parameter = 'ORDER_ID' value = '4711'
      )->returns( lth_orders=>cancelled_order( ) ).

    DATA(is_cancelled) = cut->is_cancelled( '4711' ).

    cl_abap_unit_assert=>assert_true( act = is_cancelled msg = `A cancelled order must be reported as cancelled` ).
  ENDMETHOD.


  METHOD given_unknown_order_then_raise.
    DATA(was_raised) = abap_false.
    repository->when( 'GET_ORDER' )->raises( NEW zcx_atk_demo_not_found( ) ).

    TRY.
        cut->cancel( '4711' ).
      CATCH zcx_atk_demo_not_found.
        was_raised = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true( act = was_raised msg = `An unknown order must raise ZCX_ATK_DEMO_NOT_FOUND` ).
  ENDMETHOD.


  METHOD when_cancel_then_logged_once.
    repository->when( 'GET_ORDER' )->returns( lth_orders=>open_order( ) ).

    cut->cancel( '4711' ).

    audit_log->was_called( 'WRITE'
      )->with( parameter = 'ORDER_ID' value = '4711'
      )->with( parameter = 'ACTION' value = zif_atk_demo_audit_log=>action-cancelled
      )->times( 1 ).
  ENDMETHOD.


  METHOD given_cancelled_then_no_log.
    repository->when( 'GET_ORDER' )->returns( lth_orders=>cancelled_order( ) ).

    cut->cancel( '4711' ).

    audit_log->was_not_called( 'WRITE' ).
  ENDMETHOD.


  METHOD when_cancel_then_mock_verified.
    DATA service TYPE REF TO zif_atk_demo_order_service.
    DATA(strict_log) = zcl_atk=>mock( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
    service = NEW zcl_atk_demo_order_service( repository = CAST #( repository->instance( ) )
                                              audit_log  = CAST #( strict_log->instance( ) ) ).
    repository->when( 'GET_ORDER' )->returns( lth_orders=>open_order( ) ).
    strict_log->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = zif_atk_demo_audit_log=>action-cancelled ).

    service->cancel( '4711' ).

    strict_log->verify( ).
  ENDMETHOD.

ENDCLASS.
