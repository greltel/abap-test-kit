"! Records failures instead of failing the running test, so that ATK's own tests can check them.
CLASS ltd_failure_recorder DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES lif_failure_reporter.

    TYPES ty_problems TYPE STANDARD TABLE OF zcx_atk=>ty_problem WITH EMPTY KEY.

    METHODS problems
      RETURNING VALUE(result) TYPE ty_problems.

    METHODS last_text
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    DATA failures TYPE STANDARD TABLE OF REF TO zcx_atk WITH EMPTY KEY.
ENDCLASS.


CLASS ltd_failure_recorder IMPLEMENTATION.

  METHOD lif_failure_reporter~report_during_act.
    INSERT failure INTO TABLE failures.
  ENDMETHOD.


  METHOD lif_failure_reporter~report_verification.
    INSERT failure INTO TABLE failures.
  ENDMETHOD.


  METHOD problems.
    result = VALUE #( FOR failure IN failures
                      ( failure->problem ) ).
  ENDMETHOD.


  METHOD last_text.
    IF failures IS NOT INITIAL.
      result = failures[ lines( failures ) ]->get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


"! Builds doubles that report to a recorder instead of the running test.
CLASS lth_doubles DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS factory
      IMPORTING recorder      TYPE REF TO ltd_failure_recorder
      RETURNING VALUE(result) TYPE REF TO lth_double_factory.
ENDCLASS.


CLASS lth_doubles IMPLEMENTATION.

  METHOD factory.
    result = NEW #( reporter = recorder
                    gateway  = NEW lth_atdf_gateway( ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_doubled_type DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_unknown_type_then_raises FOR TESTING.
    METHODS when_final_class_then_raises FOR TESTING.
    METHODS when_data_type_then_raises FOR TESTING.
    METHODS when_interface_then_described FOR TESTING.
    METHODS when_typo_then_suggests_name FOR TESTING.

    METHODS assert_rejected
      IMPORTING type_name TYPE csequence
                expected  TYPE zcx_atk=>ty_problem.
ENDCLASS.


CLASS ltc_doubled_type IMPLEMENTATION.

  METHOD when_unknown_type_then_raises.
    assert_rejected( type_name = 'ZIF_ATK_DOES_NOT_EXIST' expected = zcx_atk=>unknown_type ).
  ENDMETHOD.


  METHOD when_final_class_then_raises.
    assert_rejected( type_name = 'ZCL_ATK_TEST_SEALED' expected = zcx_atk=>final_class ).
  ENDMETHOD.


  METHOD when_data_type_then_raises.
    assert_rejected( type_name = '\INTERFACE=ZIF_ATK_TEST_ORDERS\TYPE=TY_ORDER'
                     expected  = zcx_atk=>not_an_object_type ).
  ENDMETHOD.


  METHOD when_interface_then_described.
    DATA(orders) = lcl_doubled_type=>describe( 'zif_atk_test_orders' ).

    DATA(get_order) = orders->find_method( 'get_order' ).

    cl_abap_unit_assert=>assert_equals( act = lines( orders->doubled_methods( ) )
                                        exp = 2
                                        msg = `GET_ORDER and COUNT_OPEN must be doubled` ).
    cl_abap_unit_assert=>assert_equals( act = get_order->call_name( )
                                        exp = `ZIF_ATK_TEST_ORDERS~GET_ORDER`
                                        msg = `A dynamic call on the double needs the interface prefix` ).
  ENDMETHOD.


  METHOD when_typo_then_suggests_name.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    TRY.
        orders->find_method( 'GET_ORDRE' ).
        cl_abap_unit_assert=>fail( `A misspelled method name must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>unknown_method_did_you_mean
                                            msg = `A close method name must be suggested` ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `GET_ORDER` )
                                          msg = `The suggestion must name GET_ORDER` ).
    ENDTRY.
  ENDMETHOD.


  METHOD assert_rejected.
    TRY.
        lcl_doubled_type=>describe( type_name ).
        cl_abap_unit_assert=>fail( |{ type_name } must be rejected| ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = expected
                                            msg = |Wrong problem reported for { type_name }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_value_conversion DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA conditions TYPE REF TO lcl_arguments.

    METHODS setup.
    METHODS given_digits_then_numc_filled FOR TESTING.
    METHODS given_letters_then_raises FOR TESTING.
    METHODS given_too_long_text_raises FOR TESTING.
    METHODS given_output_in_with_raises FOR TESTING.
    METHODS given_same_param_twice_raises FOR TESTING.
    METHODS given_typo_in_param_raises FOR TESTING.
    METHODS given_rounding_text_raises FOR TESTING.
    METHODS given_other_table_key_then_ok FOR TESTING.

    METHODS method_of
      IMPORTING type_name     TYPE csequence
                method_name   TYPE csequence
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_method.

    METHODS input_error
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                parameter_name TYPE csequence
                value          TYPE any
      RETURNING VALUE(result)  TYPE REF TO zcx_atk.
ENDCLASS.


CLASS ltc_value_conversion IMPLEMENTATION.

  METHOD setup.
    conditions = NEW #( ).
  ENDMETHOD.


  METHOD given_digits_then_numc_filled.
    DATA order_id TYPE REF TO zif_atk_test_orders=>ty_order_id.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).

    get_order->add_input( arguments = conditions parameter_name = 'order_id' value = '4711' ).

    order_id ?= conditions->value_of( 'ORDER_ID' ).
    cl_abap_unit_assert=>assert_equals( act = order_id->*
                                        exp = CONV zif_atk_test_orders=>ty_order_id( '4711' )
                                        msg = `'4711' must become the numeric text 0000004711` ).
  ENDMETHOD.


  METHOD given_letters_then_raises.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'ORDER_ID' value = '47A1' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `'47A1' must not silently lose its letter` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_does_not_fit
                                        msg = `Wrong problem for a lossy conversion` ).
  ENDMETHOD.


  METHOD given_too_long_text_raises.
    DATA(country_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'COUNTRY_NAME' ).

    DATA(error) = input_error( doubled_method = country_name parameter_name = 'CODE' value = `GREECE` ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `A value longer than the parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_does_not_fit
                                        msg = `Wrong problem for a truncated value` ).
  ENDMETHOD.


  METHOD given_output_in_with_raises.
    DATA(split_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SPLIT_NAME' ).

    DATA(error) = input_error( doubled_method = split_name parameter_name = 'FIRST_NAME' value = `Ada` ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `with( ) must reject an EXPORTING parameter` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>not_an_input
                                        msg = `Wrong problem for an output used as condition` ).
  ENDMETHOD.


  METHOD given_same_param_twice_raises.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).
    get_order->add_input( arguments = conditions parameter_name = 'ORDER_ID' value = '4711' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'ORDER_ID' value = '0815' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `A second value for the same parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_given_twice
                                        msg = `Wrong problem for a parameter given twice` ).
  ENDMETHOD.


  METHOD given_typo_in_param_raises.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'ORDERID' value = '4711' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `An unknown parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_param_did_you_mean
                                        msg = `A close parameter name must be suggested` ).
  ENDMETHOD.


  METHOD given_rounding_text_raises.
    DATA(book) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'BOOK' ).

    DATA(error) = input_error( doubled_method = book parameter_name = 'AMOUNT' value = '12.345' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `'12.345' must not be rounded silently to 12.35` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_does_not_fit
                                        msg = `Wrong problem for a rounded value` ).
  ENDMETHOD.


  METHOD given_other_table_key_then_ok.
    DATA(join_names) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'JOIN_NAMES' ).

    DATA(names) = VALUE ty_texts( ( `Ada` ) ).

    DATA(error) = input_error( doubled_method = join_names parameter_name = 'NAMES' value = names ).

    cl_abap_unit_assert=>assert_not_bound( act = error msg = `A table that differs only in its key must be accepted` ).
  ENDMETHOD.


  METHOD method_of.
    result = lcl_doubled_type=>describe( type_name )->find_method( method_name ).
  ENDMETHOD.


  METHOD input_error.
    TRY.
        doubled_method->add_input( arguments = conditions parameter_name = parameter_name value = value ).
      CATCH zcx_atk INTO result.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_stub DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA stub TYPE REF TO zif_atk_stub.
    DATA orders TYPE REF TO zif_atk_test_orders.

    METHODS setup.
    METHODS when_args_match_then_returns FOR TESTING RAISING cx_static_check.
    METHODS given_no_rules_then_initial FOR TESTING.
    METHODS when_args_differ_then_fails FOR TESTING RAISING cx_static_check.
    METHODS given_two_rules_specific_wins FOR TESTING RAISING cx_static_check.
    METHODS given_tie_then_last_rule_wins FOR TESTING RAISING cx_static_check.
    METHODS when_called_thrice_answers FOR TESTING.
    METHODS when_raises_then_caller_gets FOR TESTING.
    METHODS when_undeclared_then_raises FOR TESTING.
    METHODS when_no_check_then_accepted FOR TESTING.
    METHODS when_returns_twice_raises FOR TESTING.
ENDCLASS.


CLASS ltc_stub IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    stub = lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_ORDERS' role = lif_role=>stub ).
    orders = CAST #( stub->instance( ) ).
  ENDMETHOD.


  METHOD when_args_match_then_returns.
    DATA(acme_order) = VALUE zif_atk_test_orders=>ty_order( id = '0000004711' customer = `ACME` amount = 100 ).
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns( acme_order ).

    DATA(order) = orders->get_order( '4711' ).

    cl_abap_unit_assert=>assert_equals( act = order
                                        exp = acme_order
                                        msg = `The order configured for 4711 must be returned` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A matching call must not fail the test` ).
  ENDMETHOD.


  METHOD given_no_rules_then_initial.
    DATA(open_orders) = orders->count_open( ).

    cl_abap_unit_assert=>assert_equals( act = open_orders exp = 0 msg = `A method without rules must return initial` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A method without rules must not fail` ).
  ENDMETHOD.


  METHOD when_args_differ_then_fails.
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns(
        VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).

    DATA(order) = orders->get_order( '0815' ).

    cl_abap_unit_assert=>assert_initial( act = order msg = `A call no rule matches must return initial` ).
    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `A call no rule matches must fail the test` ).
  ENDMETHOD.


  METHOD given_two_rules_specific_wins.
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns(
        VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).
    stub->when( 'GET_ORDER' )->returns( VALUE zif_atk_test_orders=>ty_order( customer = `ANYONE` ) ).

    DATA(order_4711) = orders->get_order( '4711' ).
    DATA(order_0815) = orders->get_order( '0815' ).

    cl_abap_unit_assert=>assert_equals( act = order_4711-customer exp = `ACME` msg = `The rule with with( ) must win` ).
    cl_abap_unit_assert=>assert_equals( act = order_0815-customer exp = `ANYONE` msg = `The general rule must apply` ).
  ENDMETHOD.


  METHOD given_tie_then_last_rule_wins.
    stub->when( 'GET_ORDER' )->returns( VALUE zif_atk_test_orders=>ty_order( customer = `FIRST` ) ).
    stub->when( 'GET_ORDER' )->returns( VALUE zif_atk_test_orders=>ty_order( customer = `SECOND` ) ).

    DATA(order) = orders->get_order( '4711' ).

    cl_abap_unit_assert=>assert_equals( act = order-customer
                                        exp = `SECOND`
                                        msg = `On a tie the rule written last wins` ).
  ENDMETHOD.


  METHOD when_called_thrice_answers.
    stub->when( 'COUNT_OPEN' )->returns( 3 ).

    DATA(total) = orders->count_open( ) + orders->count_open( ) + orders->count_open( ).

    cl_abap_unit_assert=>assert_equals( act = total exp = 9 msg = `Every call must be answered, not only the first` ).
  ENDMETHOD.


  METHOD when_raises_then_caller_gets.
    DATA(was_raised) = abap_false.
    stub->when( 'GET_ORDER' )->raises( NEW zcx_atk_test_not_found( ) ).

    TRY.
        orders->get_order( '4711' ).
      CATCH zcx_atk_test_not_found.
        was_raised = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true( act = was_raised msg = `The configured exception must reach the caller` ).
  ENDMETHOD.


  METHOD when_undeclared_then_raises.
    DATA(rule) = stub->when( 'COUNT_OPEN' ).

    TRY.
        rule->raises( NEW zcx_atk_test_not_found( ) ).
        cl_abap_unit_assert=>fail( `COUNT_OPEN does not declare the exception, raises( ) must reject it` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>undeclared_exception
                                            msg = `Wrong problem for an undeclared exception` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_no_check_then_accepted.
    DATA(was_raised) = abap_false.
    stub->when( 'COUNT_OPEN' )->raises( NEW zcx_atk( problem = zcx_atk=>internal_error ) ).

    TRY.
        orders->count_open( ).
      CATCH zcx_atk.
        was_raised = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true( act = was_raised msg = `A CX_NO_CHECK exception needs no declaration` ).
  ENDMETHOD.


  METHOD when_returns_twice_raises.
    DATA(rule) = stub->when( 'COUNT_OPEN' )->returns( 1 ).

    TRY.
        rule->returns( 2 ).
        cl_abap_unit_assert=>fail( `A second returns( ) on the same rule must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>answer_already_set
                                            msg = `Wrong problem for a second answer` ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_parameter_shapes DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA stub TYPE REF TO zif_atk_stub.
    DATA shapes TYPE REF TO zif_atk_test_shapes.

    METHODS setup.
    METHODS when_sets_then_exporting_set FOR TESTING.
    METHODS when_sets_then_changing_set FOR TESTING.
    METHODS when_sets_input_then_raises FOR TESTING.
    METHODS when_no_returning_then_raises FOR TESTING.
    METHODS given_generic_input_then_works FOR TESTING.
    METHODS given_generic_table_then_works FOR TESTING.
    METHODS given_generic_mismatch_fails FOR TESTING.
    METHODS when_returns_double_then_same FOR TESTING.
ENDCLASS.


CLASS ltc_parameter_shapes IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    stub = lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_SHAPES' role = lif_role=>stub ).
    shapes = CAST #( stub->instance( ) ).
  ENDMETHOD.


  METHOD when_sets_then_exporting_set.
    stub->when( 'SPLIT_NAME'
      )->sets( parameter = 'FIRST_NAME' value = `Ada`
      )->sets( parameter = 'LAST_NAME' value = `Lovelace` ).

    shapes->split_name( EXPORTING full_name  = `Ada Lovelace`
                        IMPORTING first_name = DATA(first_name)
                                  last_name  = DATA(last_name) ).

    cl_abap_unit_assert=>assert_equals( act = |{ first_name } { last_name }|
                                        exp = `Ada Lovelace`
                                        msg = `Both EXPORTING parameters must be filled` ).
  ENDMETHOD.


  METHOD when_sets_then_changing_set.
    DATA(text) = `dirty`.
    stub->when( 'NORMALIZE' )->sets( parameter = 'TEXT' value = `clean` ).

    shapes->normalize( CHANGING text = text ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `clean` msg = `The CHANGING parameter must be changed` ).
  ENDMETHOD.


  METHOD when_sets_input_then_raises.
    DATA(rule) = stub->when( 'SPLIT_NAME' ).

    TRY.
        rule->sets( parameter = 'FULL_NAME' value = `Ada` ).
        cl_abap_unit_assert=>fail( `sets( ) must reject an IMPORTING parameter` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>not_an_output
                                            msg = `Wrong problem for an input used as output` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_no_returning_then_raises.
    DATA(rule) = stub->when( 'NORMALIZE' ).

    TRY.
        rule->returns( `clean` ).
        cl_abap_unit_assert=>fail( `returns( ) must reject a method without RETURNING` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>no_returning_parameter
                                            msg = `Wrong problem for a missing RETURNING parameter` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_generic_input_then_works.
    stub->when( 'DESCRIBE' )->with( parameter = 'ANYTHING' value = 42 )->returns( `the answer` ).

    DATA(description) = shapes->describe( 42 ).

    cl_abap_unit_assert=>assert_equals( act = description exp = `the answer` msg = `A generic input must be matched` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A generic input must not fail the test` ).
  ENDMETHOD.


  METHOD given_generic_table_then_works.
    DATA(rows) = VALUE ty_texts( ( `a` ) ( `b` ) ( `c` ) ).
    stub->when( 'COUNT_ROWS' )->returns( 3 ).

    DATA(row_count) = shapes->count_rows( rows ).

    cl_abap_unit_assert=>assert_equals( act = row_count
                                        exp = 3
                                        msg = `A generic table input must not break the double` ).
  ENDMETHOD.


  METHOD given_generic_mismatch_fails.
    stub->when( 'DESCRIBE' )->with( parameter = 'ANYTHING' value = 42 )->returns( `the answer` ).

    DATA(description) = shapes->describe( `not a number` ).

    cl_abap_unit_assert=>assert_initial( act = description msg = `A value no rule matches must return initial` ).
    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `A text compared with a number must not escape as an exception` ).
  ENDMETHOD.


  METHOD when_returns_double_then_same.
    DATA(factory) = lth_doubles=>factory( recorder ).
    DATA(other_double) = factory->create( type_name = 'ZIF_ATK_TEST_AUDIT_LOG'
                                          role      = lif_role=>stub ).
    DATA(expected_log) = other_double->zif_atk_double~instance( ).
    stub->when( 'NEW_LOG' )->returns( expected_log ).

    DATA(log) = shapes->new_log( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( log = expected_log )
                                      msg = `A double must be able to return another double` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_class_double DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_class_then_doubled FOR TESTING.
ENDCLASS.


CLASS ltc_class_double IMPLEMENTATION.

  METHOD given_class_then_doubled.
    DATA(recorder) = NEW ltd_failure_recorder( ).
    DATA(stub) = CAST zif_atk_stub( lth_doubles=>factory( recorder )->create( type_name = 'ZCL_ATK_TEST_EXTENSIBLE'
                                                                              role      = lif_role=>stub ) ).
    stub->when( 'GREET' )->with( parameter = 'NAME' value = `Ada` )->returns( `Hello Ada` ).
    DATA(greeter) = CAST zcl_atk_test_extensible( stub->instance( ) ).

    DATA(greeting) = greeter->greet( `Ada` ).

    cl_abap_unit_assert=>assert_equals( act = greeting exp = `Hello Ada` msg = `A non-final class must be doubled` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_spy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA spy TYPE REF TO zif_atk_spy.
    DATA audit_log TYPE REF TO zif_atk_test_audit_log.

    METHODS setup.
    METHODS when_called_once_then_passes FOR TESTING.
    METHODS when_argument_differs_fails FOR TESTING.
    METHODS given_no_call_then_zero_passes FOR TESTING.
    METHODS when_not_called_then_passes FOR TESTING.
    METHODS when_called_then_unwanted FOR TESTING.
    METHODS when_times_negative_raises FOR TESTING.
ENDCLASS.


CLASS ltc_spy IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    spy = lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_AUDIT_LOG' role = lif_role=>spy ).
    audit_log = CAST #( spy->instance( ) ).
  ENDMETHOD.


  METHOD when_called_once_then_passes.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    spy->was_called( 'WRITE'
      )->with( parameter = 'ORDER_ID' value = '4711'
      )->with( parameter = 'ACTION' value = `CANCELLED`
      )->times( 1 ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A matching call must pass the check` ).
  ENDMETHOD.


  METHOD when_argument_differs_fails.
    audit_log->write( order_id = '4711' action = `CANCELED` ).

    spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 1 ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>wrong_call_count ) )
                                        msg = `A differing argument must fail the check` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( recorder->last_text( ) CS `CANCELED` )
                                      msg = `The failure must show the closest actual call` ).
  ENDMETHOD.


  METHOD given_no_call_then_zero_passes.
    spy->was_called( 'WRITE' )->times( 0 ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `times( 0 ) must pass without calls` ).
  ENDMETHOD.


  METHOD when_not_called_then_passes.
    spy->was_not_called( 'WRITE' ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `No call means was_not_called( ) passes` ).
  ENDMETHOD.


  METHOD when_called_then_unwanted.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    spy->was_not_called( 'WRITE' ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>unwanted_call ) )
                                        msg = `A call must fail was_not_called( )` ).
  ENDMETHOD.


  METHOD when_times_negative_raises.
    DATA(check) = spy->was_called( 'WRITE' ).

    TRY.
        check->times( -1 ).
        cl_abap_unit_assert=>fail( `A negative number of calls must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>negative_expected_calls
                                            msg = `Wrong problem for a negative number of calls` ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_mock DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA mock TYPE REF TO zif_atk_mock.
    DATA audit_log TYPE REF TO zif_atk_test_audit_log.

    METHODS setup.
    METHODS when_expected_call_then_passes FOR TESTING.
    METHODS when_call_missing_then_fails FOR TESTING.
    METHODS when_unexpected_then_fails FOR TESTING.
    METHODS given_times_two_then_counts FOR TESTING.
    METHODS when_times_zero_then_raises FOR TESTING.
    METHODS when_expected_then_answers FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_mock IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    mock = lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_AUDIT_LOG' role = lif_role=>mock ).
    audit_log = CAST #( mock->instance( ) ).
  ENDMETHOD.


  METHOD when_expected_call_then_passes.
    mock->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `The declared call happened` ).
  ENDMETHOD.


  METHOD when_call_missing_then_fails.
    mock->expect_call( 'WRITE' ).

    mock->verify( ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>wrong_call_count ) )
                                        msg = `A declared call that did not happen must fail verify( )` ).
  ENDMETHOD.


  METHOD when_unexpected_then_fails.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>unexpected_call ) )
                                        msg = `An undeclared call must fail at once` ).
  ENDMETHOD.


  METHOD given_times_two_then_counts.
    mock->expect_call( 'WRITE' )->times( 2 ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `Two declared calls happened` ).
  ENDMETHOD.


  METHOD when_times_zero_then_raises.
    DATA(expectation) = mock->expect_call( 'WRITE' ).

    TRY.
        expectation->times( 0 ).
        cl_abap_unit_assert=>fail( `A mock expectation of zero calls must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>invalid_expected_calls
                                            msg = `Wrong problem for zero expected calls` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_expected_then_answers.
    DATA(mock_orders) = CAST zif_atk_mock( lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_ORDERS'
                                                                                     role      = lif_role=>mock ) ).
    mock_orders->expect_call( 'GET_ORDER' )->returns( VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).
    DATA(orders) = CAST zif_atk_test_orders( mock_orders->instance( ) ).

    DATA(order) = orders->get_order( '4711' ).

    mock_orders->verify( ).
    cl_abap_unit_assert=>assert_equals( act = order-customer exp = `ACME` msg = `A mock must answer like a stub` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `The declared call happened` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_dummy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_called_then_fails FOR TESTING.
ENDCLASS.


CLASS ltc_dummy IMPLEMENTATION.

  METHOD when_called_then_fails.
    DATA(recorder) = NEW ltd_failure_recorder( ).
    DATA(dummy) = CAST zif_atk_dummy( lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_AUDIT_LOG'
                                                                                role      = lif_role=>dummy ) ).
    DATA(audit_log) = CAST zif_atk_test_audit_log( dummy->instance( ) ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>dummy_called ) )
                                        msg = `Any call of a dummy must fail the test` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_facade DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_stub_then_instance_fits FOR TESTING.
    METHODS when_unknown_type_then_raises FOR TESTING.
    METHODS when_rule_matches_then_passes FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_facade IMPLEMENTATION.

  METHOD when_stub_then_instance_fits.
    DATA(stub) = zcl_atk=>stub( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(instance) = stub->instance( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( instance IS INSTANCE OF zif_atk_test_orders )
                                      msg = `The instance must implement the doubled interface` ).
  ENDMETHOD.


  METHOD when_unknown_type_then_raises.
    TRY.
        zcl_atk=>mock( 'ZIF_ATK_DOES_NOT_EXIST' ).
        cl_abap_unit_assert=>fail( `An unknown type must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>unknown_type
                                            msg = `Wrong problem for an unknown type` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_rule_matches_then_passes.
    DATA(stub) = zcl_atk=>stub( 'ZIF_ATK_TEST_ORDERS' ).
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns(
        VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).
    DATA(orders) = CAST zif_atk_test_orders( stub->instance( ) ).

    DATA(order) = orders->get_order( '4711' ).

    cl_abap_unit_assert=>assert_equals( act = order-customer exp = `ACME` msg = `The standard wiring must answer` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_exception_text DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_raised_then_text_has_fix FOR TESTING.
    METHODS when_details_then_appended FOR TESTING.
ENDCLASS.


CLASS ltc_exception_text IMPLEMENTATION.

  METHOD when_raised_then_text_has_fix.
    MESSAGE e102(zatk) WITH `ZCL_SAMPLE` INTO DATA(fix).

    DATA(error) = NEW zcx_atk( problem = zcx_atk=>final_class context = VALUE #( value1 = `ZCL_SAMPLE` ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS fix )
                                      msg = `The text must say how to fix the problem` ).
  ENDMETHOD.


  METHOD when_details_then_appended.
    DATA(error) = NEW zcx_atk( problem = zcx_atk=>unknown_method
                               context = VALUE #( value1 = `ZIF_SAMPLE` value2 = `GO` details = `Available: RUN.` ) ).

    DATA(text) = error->get_text( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `Available: RUN.` )
                                      msg = `The details must be part of the text` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_value_formatter DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_text_then_quoted FOR TESTING.
    METHODS given_number_then_plain FOR TESTING.
    METHODS given_structure_then_parts FOR TESTING.
    METHODS given_table_then_row_count FOR TESTING.
    METHODS given_long_text_then_shortened FOR TESTING.
ENDCLASS.


CLASS ltc_value_formatter IMPLEMENTATION.

  METHOD given_text_then_quoted.
    DATA(text) = lcl_value_formatter=>format( `ACME` ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `'ACME'` msg = `Texts must be quoted` ).
  ENDMETHOD.


  METHOD given_number_then_plain.
    DATA(text) = lcl_value_formatter=>format( 42 ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `42` msg = `Numbers must not be quoted` ).
  ENDMETHOD.


  METHOD given_structure_then_parts.
    DATA(order) = VALUE zif_atk_test_orders=>ty_order( id = '0000004711' customer = `ACME` amount = 12 ).

    DATA(text) = lcl_value_formatter=>format( order ).

    cl_abap_unit_assert=>assert_equals( act = text
                                        exp = `( ID = '0000004711', CUSTOMER = 'ACME', AMOUNT = 12 )`
                                        msg = `A structure must show its components` ).
  ENDMETHOD.


  METHOD given_table_then_row_count.
    MESSAGE e209(zatk) WITH `2` INTO DATA(expected).

    DATA(text) = lcl_value_formatter=>format( VALUE ty_texts( ( `a` ) ( `b` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = text exp = expected msg = `A table must show its row count` ).
  ENDMETHOD.


  METHOD given_long_text_then_shortened.
    DATA(long_text) = repeat( val = `x` occ = 500 ).

    DATA(text) = lcl_value_formatter=>format( long_text ).

    cl_abap_unit_assert=>assert_equals( act = strlen( text )
                                        exp = 203
                                        msg = `Long values must be cut at 200 characters` ).
  ENDMETHOD.

ENDCLASS.
