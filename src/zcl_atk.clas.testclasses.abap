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
    METHODS when_class_then_raises FOR TESTING.
    METHODS when_data_type_then_raises FOR TESTING.
    METHODS when_interface_then_described FOR TESTING.
    METHODS when_blank_padded_then_found FOR TESTING.
    METHODS when_typo_then_suggests_name FOR TESTING.
    METHODS when_far_typo_then_lists_names FOR TESTING.
    METHODS given_static_method_ignored FOR TESTING.
    METHODS when_atdf_name_prefixed_found FOR TESTING.
    METHODS when_atdf_name_plain_found FOR TESTING.
    METHODS when_atdf_name_unknown_raises FOR TESTING.

    METHODS assert_rejected
      IMPORTING type_name TYPE csequence
                expected  TYPE zcx_atk=>ty_problem.

    METHODS method_error
      IMPORTING doubled_type  TYPE REF TO lcl_doubled_type
                method_name   TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zcx_atk.
ENDCLASS.


CLASS ltc_doubled_type IMPLEMENTATION.

  METHOD when_unknown_type_then_raises.
    assert_rejected( type_name = 'ZIF_ATK_DOES_NOT_EXIST' expected = zcx_atk=>unknown_type ).
  ENDMETHOD.


  METHOD when_class_then_raises.
    assert_rejected( type_name = 'ZCL_ATK' expected = zcx_atk=>not_an_interface ).
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


  METHOD when_blank_padded_then_found.
    DATA(orders) = lcl_doubled_type=>describe( `  zif_atk_test_orders ` ).

    DATA(get_order) = orders->find_method( ` get_order ` ).

    cl_abap_unit_assert=>assert_equals( act = orders->name( )
                                        exp = `ZIF_ATK_TEST_ORDERS`
                                        msg = `Blanks around the type name must be ignored` ).
    cl_abap_unit_assert=>assert_equals( act = get_order->name( )
                                        exp = `GET_ORDER`
                                        msg = `Blanks around the method name must be ignored` ).
  ENDMETHOD.


  METHOD when_typo_then_suggests_name.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(error) = method_error( doubled_type = orders method_name = 'GET_ORDRE' ).

    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_method_did_you_mean
                                        msg = `A close method name must be suggested` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `GET_ORDER` )
                                      msg = `The suggestion must name GET_ORDER` ).
  ENDMETHOD.


  METHOD when_far_typo_then_lists_names.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(error) = method_error( doubled_type = orders method_name = 'XYZXYZ' ).

    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_method
                                        msg = `A name far from every method gets the list instead of a suggestion` ).
    DATA(text) = error->get_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `GET_ORDER` AND text CS `COUNT_OPEN` )
                                      msg = `The text must list the methods that can be doubled` ).
  ENDMETHOD.


  METHOD given_static_method_ignored.
    DATA(shapes) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_SHAPES' ).

    DATA(error) = method_error( doubled_type = shapes method_name = 'VERSION' ).

    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_method
                                        msg = `A static method cannot be doubled and must be reported as unknown` ).
  ENDMETHOD.


  METHOD when_atdf_name_prefixed_found.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(get_order) = orders->method_called_by_atdf( 'ZIF_ATK_TEST_ORDERS~GET_ORDER' ).

    cl_abap_unit_assert=>assert_equals( act = get_order->name( )
                                        exp = `GET_ORDER`
                                        msg = `The interface prefix ATDF reports must be stripped` ).
  ENDMETHOD.


  METHOD when_atdf_name_plain_found.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(get_order) = orders->method_called_by_atdf( 'get_order' ).

    cl_abap_unit_assert=>assert_equals( act = get_order->name( )
                                        exp = `GET_ORDER`
                                        msg = `A method name without prefix must be found too` ).
  ENDMETHOD.


  METHOD when_atdf_name_unknown_raises.
    DATA(orders) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' ).

    TRY.
        orders->method_called_by_atdf( 'ZIF_ATK_TEST_ORDERS~NOPE' ).
        cl_abap_unit_assert=>fail( `A method ATK never routed must be reported as internal error` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>internal_error
                                            msg = `Wrong problem for an unknown ATDF method name` ).
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


  METHOD method_error.
    TRY.
        doubled_type->find_method( method_name ).
        cl_abap_unit_assert=>fail( |{ method_name } must be rejected| ).
      CATCH zcx_atk INTO result.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_component_interface DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA spy TYPE REF TO zif_atk_spy.
    DATA archive TYPE REF TO zif_atk_test_archive.

    METHODS setup.
    METHODS when_described_then_two_listed FOR TESTING.
    METHODS when_plain_name_then_component FOR TESTING.
    METHODS when_component_called_seen FOR TESTING.
    METHODS when_own_method_then_answered FOR TESTING.
    METHODS when_component_args_differ FOR TESTING.
ENDCLASS.


CLASS ltc_component_interface IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    spy = lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_ARCHIVE' role = lif_role=>spy ).
    archive = CAST #( spy->instance( ) ).
  ENDMETHOD.


  METHOD when_described_then_two_listed.
    DATA(described) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ARCHIVE' ).

    DATA(write) = described->find_method( 'ZIF_ATK_TEST_AUDIT_LOG~WRITE' ).

    cl_abap_unit_assert=>assert_equals( act = lines( described->doubled_methods( ) )
                                        exp = 2
                                        msg = `PURGE and the WRITE of the component must be doubled` ).
    cl_abap_unit_assert=>assert_equals( act = write->call_name( )
                                        exp = `ZIF_ATK_TEST_AUDIT_LOG~WRITE`
                                        msg = `A component method is called with its own interface prefix` ).
  ENDMETHOD.


  METHOD when_plain_name_then_component.
    DATA(described) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ARCHIVE' ).

    DATA(write) = described->find_method( 'WRITE' ).

    cl_abap_unit_assert=>assert_equals( act = write->name( )
                                        exp = `ZIF_ATK_TEST_AUDIT_LOG~WRITE`
                                        msg = `WRITE alone must find the only method of that name` ).
  ENDMETHOD.


  METHOD when_component_called_seen.
    archive->zif_atk_test_audit_log~write( order_id = '4711' action = `ARCHIVED` ).

    spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `ARCHIVED` )->times( 1 ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( )
                                         msg = `A call of a component method must be recorded and matched` ).
  ENDMETHOD.


  METHOD when_own_method_then_answered.
    spy->when( 'PURGE' )->returns( 3 ).

    DATA(purged) = archive->purge( ).

    cl_abap_unit_assert=>assert_equals( act = purged exp = 3 msg = `The own method of the interface must be answered` ).
  ENDMETHOD.


  METHOD when_component_args_differ.
    spy->when( 'ZIF_ATK_TEST_AUDIT_LOG~WRITE' )->with( parameter = 'ORDER_ID' value = '4711' ).

    archive->zif_atk_test_audit_log~write( order_id = '0815' action = `ARCHIVED` ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `Rules on a component method must be applied to its calls` ).
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
    METHODS given_changing_in_with_then_ok FOR TESTING.
    METHODS given_same_param_twice_raises FOR TESTING.
    METHODS given_typo_in_param_raises FOR TESTING.
    METHODS given_far_typo_then_lists FOR TESTING.
    METHODS given_rounding_text_raises FOR TESTING.
    METHODS given_number_for_text_then_ok FOR TESTING.
    METHODS given_other_table_key_then_ok FOR TESTING.
    METHODS given_structure_then_ok FOR TESTING.
    METHODS given_other_structure_raises FOR TESTING.
    METHODS given_text_for_return_raises FOR TESTING.
    METHODS given_number_for_ref_raises FOR TESTING.
    METHODS given_table_for_output_raises FOR TESTING.
    METHODS given_lossy_then_shows_result FOR TESTING.
    METHODS given_wrong_kind_then_says_so FOR TESTING.
    METHODS given_other_type_then_names_it FOR TESTING.
    METHODS given_no_outputs_then_says_so FOR TESTING.

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


  METHOD given_changing_in_with_then_ok.
    DATA(normalize) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'NORMALIZE' ).

    DATA(error) = input_error( doubled_method = normalize parameter_name = 'TEXT' value = `dirty` ).

    cl_abap_unit_assert=>assert_not_bound( act = error msg = `A CHANGING parameter is an input too` ).
    cl_abap_unit_assert=>assert_true( act = conditions->has( 'TEXT' ) msg = `The condition must be stored` ).
  ENDMETHOD.


  METHOD given_same_param_twice_raises.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).
    get_order->add_input( arguments = conditions parameter_name = 'ORDER_ID' value = '4711' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'ORDER_ID' value = '0815' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `A second value for the same parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_given_twice
                                        msg = `Wrong problem for a parameter given twice` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `'0000004711'` )
                                      msg = `The text must show the value the parameter already has` ).
  ENDMETHOD.


  METHOD given_typo_in_param_raises.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'ORDERID' value = '4711' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `An unknown parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_param_did_you_mean
                                        msg = `A close parameter name must be suggested` ).
  ENDMETHOD.


  METHOD given_far_typo_then_lists.
    DATA(get_order) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'GET_ORDER' ).

    DATA(error) = input_error( doubled_method = get_order parameter_name = 'XYZXYZ' value = '4711' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `An unknown parameter must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>unknown_parameter
                                        msg = `A name far from every parameter gets the list instead of a suggestion` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `ORDER_ID` )
                                      msg = `The text must list the parameters of the method` ).
  ENDMETHOD.


  METHOD given_rounding_text_raises.
    DATA(book) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'BOOK' ).

    DATA(error) = input_error( doubled_method = book parameter_name = 'AMOUNT' value = '12.345' ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `'12.345' must not be rounded silently to 12.35` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_does_not_fit
                                        msg = `Wrong problem for a rounded value` ).
  ENDMETHOD.


  METHOD given_number_for_text_then_ok.
    DATA full_name TYPE REF TO string.
    DATA(split_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SPLIT_NAME' ).

    DATA(error) = input_error( doubled_method = split_name parameter_name = 'FULL_NAME' value = 42 ).

    cl_abap_unit_assert=>assert_not_bound( act = error msg = `A number fits a text parameter` ).
    full_name ?= conditions->value_of( 'FULL_NAME' ).
    cl_abap_unit_assert=>assert_equals( act = condense( full_name->* )
                                        exp = `42`
                                        msg = `The number must become its text` ).
  ENDMETHOD.


  METHOD given_other_table_key_then_ok.
    DATA(join_names) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'JOIN_NAMES' ).

    DATA(names) = VALUE ty_texts( ( `Ada` ) ).

    DATA(error) = input_error( doubled_method = join_names parameter_name = 'NAMES' value = names ).

    cl_abap_unit_assert=>assert_not_bound( act = error msg = `A table that differs only in its key must be accepted` ).
  ENDMETHOD.


  METHOD given_structure_then_ok.
    DATA(save) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SAVE' ).
    DATA(order) = VALUE zif_atk_test_orders=>ty_order( id = '0000004711' customer = `ACME` ).

    DATA(error) = input_error( doubled_method = save parameter_name = 'ORDER' value = order ).

    cl_abap_unit_assert=>assert_not_bound( act = error msg = `A structure of the parameter type must be accepted` ).
  ENDMETHOD.


  METHOD given_other_structure_raises.
    DATA(save) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SAVE' ).
    DATA(other) = VALUE lcl_doubled_method=>ty_naming( name = `ACME` ).

    DATA(error) = input_error( doubled_method = save parameter_name = 'ORDER' value = other ).

    cl_abap_unit_assert=>assert_bound( act = error msg = `A structure of another type must be rejected` ).
    cl_abap_unit_assert=>assert_equals( act = error->problem
                                        exp = zcx_atk=>value_does_not_fit
                                        msg = `Wrong problem for a structure of another type` ).
  ENDMETHOD.


  METHOD given_text_for_return_raises.
    DATA(count_open) = method_of( type_name = 'ZIF_ATK_TEST_ORDERS' method_name = 'COUNT_OPEN' ).

    TRY.
        count_open->returning_value( `many` ).
        cl_abap_unit_assert=>fail( `A text must not become the RETURNING value of an integer method` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>value_does_not_fit
                                            msg = `Wrong problem for a RETURNING value of the wrong type` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_number_for_ref_raises.
    DATA(new_log) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'NEW_LOG' ).

    TRY.
        new_log->returning_value( 42 ).
        cl_abap_unit_assert=>fail( `A number must not become an object reference` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>value_does_not_fit
                                            msg = `Wrong problem for a number given for a reference` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_lossy_then_shows_result.
    MESSAGE e226(zatk) INTO DATA(would_hold).
    would_hold = |{ would_hold } 'GRE'.|.
    DATA(country_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'COUNTRY_NAME' ).

    DATA(error) = input_error( doubled_method = country_name parameter_name = 'CODE' value = `GREECE` ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS would_hold )
                                      msg = `The text must show what the parameter would hold instead` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `C LENGTH 3` )
                                      msg = `The text must show the technical type of the parameter` ).
  ENDMETHOD.


  METHOD given_wrong_kind_then_says_so.
    MESSAGE e229(zatk) INTO DATA(table).
    MESSAGE e227(zatk) INTO DATA(single_value).
    MESSAGE e224(zatk) WITH table single_value INTO DATA(cannot_become).
    DATA(split_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SPLIT_NAME' ).

    DATA(names) = VALUE ty_texts( ( `Ada` ) ).

    DATA(error) = input_error( doubled_method = split_name parameter_name = 'FULL_NAME' value = names ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS cannot_become )
                                      msg = `The text must say that a table cannot become a single value` ).
  ENDMETHOD.


  METHOD given_other_type_then_names_it.
    DATA(save) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SAVE' ).
    DATA(other) = VALUE zif_atk_demo_order_repo=>ty_order( id = '4711' ).
    DATA(other_type) = cl_abap_typedescr=>describe_by_data( other )->absolute_name.
    MESSAGE e225(zatk) INTO DATA(has_the_type).
    has_the_type = |{ has_the_type } { other_type }.|.

    DATA(error) = input_error( doubled_method = save parameter_name = 'ORDER' value = other ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS has_the_type )
                                      msg = `The text must name the type of the value in full` ).
  ENDMETHOD.


  METHOD given_no_outputs_then_says_so.
    MESSAGE e217(zatk) INTO DATA(no_outputs).
    DATA(write) = method_of( type_name = 'ZIF_ATK_TEST_AUDIT_LOG' method_name = 'WRITE' ).

    TRY.
        write->returning_value( 1 ).
        cl_abap_unit_assert=>fail( `WRITE has no RETURNING parameter` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS no_outputs )
                                          msg = `The text must say that the method has no outputs at all` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_table_for_output_raises.
    DATA(split_name) = method_of( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SPLIT_NAME' ).

    TRY.
        split_name->add_output( arguments      = conditions
                                parameter_name = 'FIRST_NAME'
                                value          = VALUE ty_texts( ( `Ada` ) ) ).
        cl_abap_unit_assert=>fail( `A table must not become the value of a text parameter` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>value_does_not_fit
                                            msg = `Wrong problem for an output value of the wrong type` ).
    ENDTRY.
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
    METHODS when_args_differ_then_explains FOR TESTING RAISING cx_static_check.
    METHODS when_unmatched_names_caller FOR TESTING RAISING cx_static_check.
    METHODS given_two_rules_specific_wins FOR TESTING RAISING cx_static_check.
    METHODS given_tie_then_last_rule_wins FOR TESTING RAISING cx_static_check.
    METHODS when_called_thrice_answers FOR TESTING.
    METHODS when_raises_then_caller_gets FOR TESTING.
    METHODS when_undeclared_then_raises FOR TESTING.
    METHODS when_no_check_then_accepted FOR TESTING.
    METHODS when_raises_unbound_raises FOR TESTING.
    METHODS when_returns_twice_raises FOR TESTING.
    METHODS when_raise_after_return_raises FOR TESTING.
    METHODS when_return_after_raise_raises FOR TESTING.
    METHODS when_unknown_method_raises FOR TESTING.
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


  METHOD when_args_differ_then_explains.
    MESSAGE e214(zatk) INTO DATA(rules).
    MESSAGE e215(zatk) INTO DATA(closest_differs_in).
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns(
        VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).

    orders->get_order( '0815' ).

    DATA(text) = recorder->last_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `ORDER_ID = '0000000815'` )
                                      msg = `The failure must show the actual arguments` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ rules } (ORDER_ID = '0000004711').| )
                                      msg = `The failure must list the rules of the method` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ closest_differs_in } ORDER_ID.| )
                                      msg = `The failure must say where the closest rule differs` ).
  ENDMETHOD.


  METHOD when_unmatched_names_caller.
    " needs the real call stack: off-stack the XCO stand-in has none (skipped in abap_transpile.json)
    MESSAGE e233(zatk) INTO DATA(called_from).
    stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns(
        VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).

    orders->get_order( '0815' ).

    DATA(text) = recorder->last_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ called_from } ZCL_ATK=>WHEN_UNMATCHED_NAMES_CALLER| )
                                      msg = |The failure must say which method made the call: { text }| ).
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

    DATA(first_call) = orders->get_order( '4711' ).
    DATA(second_call) = orders->get_order( '4711' ).

    cl_abap_unit_assert=>assert_equals( act = first_call-customer
                                        exp = `SECOND`
                                        msg = `On a tie the rule written last wins` ).
    cl_abap_unit_assert=>assert_equals( act = second_call-customer
                                        exp = `SECOND`
                                        msg = `A stub rule keeps answering, it is never used up` ).
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


  METHOD when_raises_unbound_raises.
    DATA no_exception TYPE REF TO cx_root.
    DATA(rule) = stub->when( 'GET_ORDER' ).

    TRY.
        rule->raises( no_exception ).
        cl_abap_unit_assert=>fail( `raises( ) without an exception object must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>missing_exception
                                            msg = `Wrong problem for a missing exception object` ).
    ENDTRY.
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
        cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `returns( )` )
                                          msg = `The text must name the answer the rule already has` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_raise_after_return_raises.
    DATA(rule) = stub->when( 'COUNT_OPEN' )->returns( 1 ).

    TRY.
        rule->raises( NEW zcx_atk( problem = zcx_atk=>internal_error ) ).
        cl_abap_unit_assert=>fail( `A rule cannot both return and raise` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>answer_already_set
                                            msg = `Wrong problem for raises( ) after returns( )` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_return_after_raise_raises.
    DATA(rule) = stub->when( 'COUNT_OPEN' ).
    rule->raises( NEW zcx_atk( problem = zcx_atk=>internal_error ) ).

    TRY.
        rule->returns( 1 ).
        cl_abap_unit_assert=>fail( `A rule cannot both raise and return` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>answer_already_set
                                            msg = `Wrong problem for returns( ) after raises( )` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_unknown_method_raises.
    TRY.
        stub->when( 'GET_ORDRE' ).
        cl_abap_unit_assert=>fail( `when( ) must reject a misspelled method` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>unknown_method_did_you_mean
                                            msg = `when( ) must suggest the closest method name` ).
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
    METHODS when_sets_twice_same_raises FOR TESTING.
    METHODS when_sets_after_raises_raises FOR TESTING.
    METHODS when_no_returning_then_raises FOR TESTING.
    METHODS when_with_on_changing_matches FOR TESTING.
    METHODS given_generic_input_then_works FOR TESTING.
    METHODS given_generic_table_then_works FOR TESTING.
    METHODS given_generic_mismatch_fails FOR TESTING.
    METHODS given_number_as_text_matches FOR TESTING.
    METHODS given_structure_then_matches FOR TESTING.
    METHODS given_structure_differs_fails FOR TESTING.
    METHODS given_table_then_matches FOR TESTING.
    METHODS given_optional_given_matches FOR TESTING.
    METHODS given_optional_left_out_fails FOR TESTING.
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


  METHOD when_sets_twice_same_raises.
    DATA(rule) = stub->when( 'SPLIT_NAME' )->sets( parameter = 'FIRST_NAME' value = `Ada` ).

    TRY.
        rule->sets( parameter = 'FIRST_NAME' value = `Grace` ).
        cl_abap_unit_assert=>fail( `A second value for the same output must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>value_given_twice
                                            msg = `Wrong problem for an output given twice` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_sets_after_raises_raises.
    DATA(rule) = stub->when( 'SPLIT_NAME' ).
    rule->raises( NEW zcx_atk( problem = zcx_atk=>internal_error ) ).

    TRY.
        rule->sets( parameter = 'FIRST_NAME' value = `Ada` ).
        cl_abap_unit_assert=>fail( `A rule cannot both raise and set an output` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>answer_already_set
                                            msg = `Wrong problem for sets( ) after raises( )` ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `raises( )` )
                                          msg = `The text must name the answer the rule already has` ).
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
        cl_abap_unit_assert=>assert_true( act = xsdbool( error->get_text( ) CS `TEXT (CHANGING)` )
                                          msg = `The text must list the outputs the method does have` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_with_on_changing_matches.
    DATA(dirty) = `dirty`.
    DATA(other) = `other`.
    stub->when( 'NORMALIZE' )->with( parameter = 'TEXT' value = `dirty` )->sets( parameter = 'TEXT' value = `clean` ).

    shapes->normalize( CHANGING text = dirty ).
    shapes->normalize( CHANGING text = other ).

    cl_abap_unit_assert=>assert_equals( act = dirty
                                        exp = `clean`
                                        msg = `The matching CHANGING value must be replaced` ).
    cl_abap_unit_assert=>assert_equals( act = other exp = `other` msg = `A CHANGING value no rule matches stays` ).
    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `Only the call with another CHANGING value must fail` ).
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


  METHOD given_number_as_text_matches.
    stub->when( 'DESCRIBE' )->with( parameter = 'ANYTHING' value = 42 )->returns( `the answer` ).

    DATA(description) = shapes->describe( `42` ).

    cl_abap_unit_assert=>assert_equals( act = description exp = `the answer` msg = `Text of the number must match` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `Text of the number must not fail` ).
  ENDMETHOD.


  METHOD given_structure_then_matches.
    DATA(order) = VALUE zif_atk_test_orders=>ty_order( id = '0000004711' customer = `ACME` amount = 100 ).
    stub->when( 'SAVE' )->with( parameter = 'ORDER' value = order ).

    shapes->save( order ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `An equal structure must match the rule` ).
  ENDMETHOD.


  METHOD given_structure_differs_fails.
    DATA(order) = VALUE zif_atk_test_orders=>ty_order( id = '0000004711' customer = `ACME` amount = 100 ).
    stub->when( 'SAVE' )->with( parameter = 'ORDER' value = order ).

    shapes->save( VALUE #( BASE order amount = 99 ) ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `A structure that differs in one component must not match` ).
  ENDMETHOD.


  METHOD given_table_then_matches.
    DATA(names) = VALUE zif_atk_test_shapes=>ty_names( ( `Ada` ) ( `Grace` ) ).
    stub->when( 'JOIN_NAMES' )->with( parameter = 'NAMES' value = names )->returns( `Ada, Grace` ).

    DATA(joined) = shapes->join_names( names ).

    cl_abap_unit_assert=>assert_equals( act = joined exp = `Ada, Grace` msg = `An equal table must match the rule` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `An equal table must not fail` ).
  ENDMETHOD.


  METHOD given_optional_given_matches.
    stub->when( 'GREET' )->with( parameter = 'SALUTATION' value = `Hi` )->returns( `Hi Ada` ).

    DATA(greeting) = shapes->greet( salutation = `Hi` name = `Ada` ).

    cl_abap_unit_assert=>assert_equals( act = greeting
                                        exp = `Hi Ada`
                                        msg = `A supplied optional parameter must match` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( )
                                         msg = `A supplied optional parameter must not fail` ).
  ENDMETHOD.


  METHOD given_optional_left_out_fails.
    " a parameter the caller leaves out is recorded as initial, even if it has a DEFAULT value
    " that ATK cannot see; so the rule does not match, and the failure says why
    stub->when( 'GREET' )->with( parameter = 'SALUTATION' value = `Hello` )->returns( `Hello Ada` ).

    shapes->greet( `Ada` ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_rule ) )
                                        msg = `A condition on a parameter the caller left out is not met` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( recorder->last_text( ) CS `SALUTATION = '' (not supplied)` )
                                      msg = `The failure must say that the parameter was not supplied` ).
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


CLASS ltc_spy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA spy TYPE REF TO zif_atk_spy.
    DATA audit_log TYPE REF TO zif_atk_test_audit_log.

    METHODS setup.
    METHODS when_called_once_then_passes FOR TESTING.
    METHODS when_called_twice_then_counts FOR TESTING.
    METHODS when_argument_differs_fails FOR TESTING.
    METHODS given_no_call_then_zero_passes FOR TESTING.
    METHODS given_no_call_then_says_so FOR TESTING.
    METHODS when_not_called_then_passes FOR TESTING.
    METHODS when_called_then_unwanted FOR TESTING.
    METHODS when_unwanted_then_lists_calls FOR TESTING.
    METHODS when_unwanted_names_caller FOR TESTING.
    METHODS when_times_negative_raises FOR TESTING.
    METHODS when_with_unknown_param_raises FOR TESTING.
    METHODS when_unknown_method_raises FOR TESTING.
    METHODS when_spy_answers_and_records FOR TESTING.
    METHODS when_too_many_then_lists_them FOR TESTING.
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


  METHOD when_called_twice_then_counts.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).
    audit_log->write( order_id = '4711' action = `SHIPPED` ).

    spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 2 ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `Only the matching calls must be counted` ).
  ENDMETHOD.


  METHOD when_argument_differs_fails.
    audit_log->write( order_id = '4711' action = `CANCELED` ).

    spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 1 ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>wrong_call_count ) )
                                        msg = `A differing argument must fail the check` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( recorder->last_text( ) CS `CANCELED` )
                                      msg = `The failure must show the closest actual call` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( recorder->last_text( ) CS `ACTION.` )
                                      msg = `The failure must name the parameter that differs` ).
  ENDMETHOD.


  METHOD given_no_call_then_zero_passes.
    spy->was_called( 'WRITE' )->times( 0 ).

    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `times( 0 ) must pass without calls` ).
  ENDMETHOD.


  METHOD given_no_call_then_says_so.
    MESSAGE e205(zatk) INTO DATA(no_call_recorded).

    spy->was_called( 'WRITE' )->times( 1 ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>wrong_call_count ) )
                                        msg = `A missing call must fail the check` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( recorder->last_text( ) CS no_call_recorded )
                                      msg = `The failure must say that no call was recorded` ).
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


  METHOD when_unwanted_then_lists_calls.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `SHIPPED` ).

    spy->was_not_called( 'WRITE' ).

    DATA(text) = recorder->last_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `0000004711` AND text CS `SHIPPED` )
                                      msg = `The failure must list the recorded calls` ).
  ENDMETHOD.


  METHOD when_unwanted_names_caller.
    " needs the real call stack: off-stack the XCO stand-in has none (skipped in abap_transpile.json)
    MESSAGE e232(zatk) INTO DATA(from).
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    spy->was_not_called( 'WRITE' ).

    DATA(text) = recorder->last_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ from } ZCL_ATK=>WHEN_UNWANTED_NAMES_CALLER| )
                                      msg = |The listed call must say which method made it: { text }| ).
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


  METHOD when_with_unknown_param_raises.
    DATA(check) = spy->was_called( 'WRITE' ).

    TRY.
        check->with( parameter = 'ORDERID' value = '4711' ).
        cl_abap_unit_assert=>fail( `with( ) of a check must reject an unknown parameter` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>unknown_param_did_you_mean
                                            msg = `with( ) of a check must suggest the closest parameter` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_unknown_method_raises.
    TRY.
        spy->was_not_called( 'DELETE' ).
        cl_abap_unit_assert=>fail( `was_not_called( ) must reject a method that does not exist` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>unknown_method
                                            msg = `Wrong problem for a method that does not exist` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_too_many_then_lists_them.
    MESSAGE e221(zatk) INTO DATA(matching_calls).
    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).

    spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 1 ).

    DATA(text) = recorder->last_text( ).
    DATA(lists_both) = xsdbool( text CS matching_calls AND text CS `0000004711` AND text CS `0000000815` ).
    cl_abap_unit_assert=>assert_true( act = lists_both
                                      msg = `Too many calls: the failure must list the matching calls` ).
  ENDMETHOD.


  METHOD when_spy_answers_and_records.
    DATA(factory) = lth_doubles=>factory( recorder ).
    DATA(orders_spy) = CAST zif_atk_spy( factory->create( type_name = 'ZIF_ATK_TEST_ORDERS' role = lif_role=>spy ) ).
    DATA(orders) = CAST zif_atk_test_orders( orders_spy->instance( ) ).
    orders_spy->when( 'COUNT_OPEN' )->returns( 2 ).

    DATA(open_orders) = orders->count_open( ).

    orders_spy->was_called( 'COUNT_OPEN' )->times( 1 ).
    cl_abap_unit_assert=>assert_equals( act = open_orders exp = 2 msg = `A spy must answer like a stub` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A spy must record the answered call` ).
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
    METHODS when_unexpected_then_explains FOR TESTING.
    METHODS when_args_differ_then_explains FOR TESTING.
    METHODS given_times_two_then_counts FOR TESTING.
    METHODS when_called_too_often_fails FOR TESTING.
    METHODS given_two_expectations_met FOR TESTING.
    METHODS given_specific_and_general FOR TESTING.
    METHODS when_times_zero_then_raises FOR TESTING.
    METHODS when_expected_then_answers FOR TESTING RAISING cx_static_check.
    METHODS when_expected_then_sets_output FOR TESTING.
    METHODS when_expected_then_raises FOR TESTING.

    METHODS mock_of
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zif_atk_mock.
ENDCLASS.


CLASS ltc_mock IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    mock = mock_of( 'ZIF_ATK_TEST_AUDIT_LOG' ).
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


  METHOD when_unexpected_then_explains.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    DATA(text) = recorder->last_text( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `WRITE` AND text CS `CANCELLED` )
                                      msg = `The failure must name the method and show the arguments` ).
  ENDMETHOD.


  METHOD when_args_differ_then_explains.
    MESSAGE e222(zatk) INTO DATA(expectations).
    MESSAGE e223(zatk) INTO DATA(closest_differs_in).
    mock->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` ).

    audit_log->write( order_id = '4711' action = `CANCELED` ).

    DATA(text) = recorder->last_text( ).
    DATA(expected_problems) = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>no_matching_expectation ) ).
    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = expected_problems
                                        msg = `A call no expectation matches is its own problem` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ expectations } (ACTION = 'CANCELLED').| )
                                      msg = `The failure must list the expectations of the method` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS |{ closest_differs_in } ACTION.| )
                                      msg = `The failure must say where the closest expectation differs` ).
  ENDMETHOD.


  METHOD given_times_two_then_counts.
    mock->expect_call( 'WRITE' )->times( 2 ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `Two declared calls happened` ).
  ENDMETHOD.


  METHOD when_called_too_often_fails.
    mock->expect_call( 'WRITE' ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>wrong_call_count ) )
                                        msg = `More calls than declared must fail verify( )` ).
  ENDMETHOD.


  METHOD given_two_expectations_met.
    mock->expect_call( 'WRITE' )->with( parameter = 'ORDER_ID' value = '4711' ).
    mock->expect_call( 'WRITE' )->with( parameter = 'ORDER_ID' value = '0815' ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `CANCELLED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( )
                                         msg = `Each expectation must be met by its own call` ).
  ENDMETHOD.


  METHOD given_specific_and_general.
    mock->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` ).
    mock->expect_call( 'WRITE' ).

    audit_log->write( order_id = '4711' action = `CANCELLED` ).
    audit_log->write( order_id = '0815' action = `SHIPPED` ).

    mock->verify( ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( )
                                         msg = `The specific expectation takes its call, the general one the other` ).
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
    DATA(mock_orders) = mock_of( 'ZIF_ATK_TEST_ORDERS' ).
    mock_orders->expect_call( 'GET_ORDER' )->returns( VALUE zif_atk_test_orders=>ty_order( customer = `ACME` ) ).
    DATA(orders) = CAST zif_atk_test_orders( mock_orders->instance( ) ).

    DATA(order) = orders->get_order( '4711' ).

    mock_orders->verify( ).
    cl_abap_unit_assert=>assert_equals( act = order-customer exp = `ACME` msg = `A mock must answer like a stub` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `The declared call happened` ).
  ENDMETHOD.


  METHOD when_expected_then_sets_output.
    DATA(mock_shapes) = mock_of( 'ZIF_ATK_TEST_SHAPES' ).
    mock_shapes->expect_call( 'SPLIT_NAME' )->sets( parameter = 'FIRST_NAME' value = `Ada` ).
    DATA(shapes) = CAST zif_atk_test_shapes( mock_shapes->instance( ) ).

    shapes->split_name( EXPORTING full_name = `Ada Lovelace` IMPORTING first_name = DATA(first_name) ).

    mock_shapes->verify( ).
    cl_abap_unit_assert=>assert_equals( act = first_name
                                        exp = `Ada`
                                        msg = `An expectation must set outputs like a rule` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `The declared call happened` ).
  ENDMETHOD.


  METHOD when_expected_then_raises.
    DATA(was_raised) = abap_false.
    DATA(mock_orders) = mock_of( 'ZIF_ATK_TEST_ORDERS' ).
    mock_orders->expect_call( 'COUNT_OPEN' )->raises( NEW zcx_atk( problem = zcx_atk=>internal_error ) ).
    DATA(orders) = CAST zif_atk_test_orders( mock_orders->instance( ) ).

    TRY.
        orders->count_open( ).
      CATCH zcx_atk.
        was_raised = abap_true.
    ENDTRY.

    mock_orders->verify( ).
    cl_abap_unit_assert=>assert_true( act = was_raised msg = `An expectation must raise like a rule` ).
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( )
                                         msg = `The raising call counts as the declared call` ).
  ENDMETHOD.


  METHOD mock_of.
    result = lth_doubles=>factory( recorder )->create( type_name = type_name role = lif_role=>mock ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_dummy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA recorder TYPE REF TO ltd_failure_recorder.
    DATA audit_log TYPE REF TO zif_atk_test_audit_log.

    METHODS setup.
    METHODS when_called_then_fails FOR TESTING.
    METHODS when_called_then_names_call FOR TESTING.
    METHODS when_not_called_then_passes FOR TESTING.
ENDCLASS.


CLASS ltc_dummy IMPLEMENTATION.

  METHOD setup.
    recorder = NEW #( ).
    DATA(dummy) = CAST zif_atk_dummy( lth_doubles=>factory( recorder )->create( type_name = 'ZIF_ATK_TEST_AUDIT_LOG'
                                                                                role      = lif_role=>dummy ) ).
    audit_log = CAST #( dummy->instance( ) ).
  ENDMETHOD.


  METHOD when_called_then_fails.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>dummy_called ) )
                                        msg = `Any call of a dummy must fail the test` ).
  ENDMETHOD.


  METHOD when_called_then_names_call.
    audit_log->write( order_id = '4711' action = `CANCELLED` ).

    DATA(text) = recorder->last_text( ).

    DATA(names_all) = xsdbool( text CS `ZIF_ATK_TEST_AUDIT_LOG` AND text CS `WRITE` AND text CS `CANCELLED` ).
    cl_abap_unit_assert=>assert_true( act = names_all
                                      msg = `The failure must name the double, the method and the arguments` ).
  ENDMETHOD.


  METHOD when_not_called_then_passes.
    cl_abap_unit_assert=>assert_initial( act = recorder->problems( ) msg = `A dummy that is never called is fine` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_call_router DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_unknown_method_internal FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_call_router IMPLEMENTATION.

  METHOD when_unknown_method_internal.
    " nothing may escape from the answer into the code under test, not even an ATK bug
    DATA no_arguments TYPE REF TO if_abap_testdouble_arguments.
    DATA no_handle TYPE REF TO if_abap_testdouble_handle.
    DATA atdf_result TYPE REF TO if_abap_testdouble_result.
    DATA(recorder) = NEW ltd_failure_recorder( ).
    DATA(router) = NEW lcl_call_router( doubled_type = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' )
                                        role         = lif_role=>stub
                                        reporter     = recorder ).

    router->if_abap_testdouble_answer~answer( EXPORTING arguments     = no_arguments
                                                        double_handle = no_handle
                                                        method_name   = 'ZIF_ATK_TEST_ORDERS~NOPE'
                                              CHANGING  result        = atdf_result ).

    cl_abap_unit_assert=>assert_equals( act = recorder->problems( )
                                        exp = VALUE ltd_failure_recorder=>ty_problems( ( zcx_atk=>internal_error ) )
                                        msg = `A method ATK never routed must be reported, not raised` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_call_journal DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_origin_then_shown FOR TESTING.
    METHODS given_no_origin_then_args_only FOR TESTING.

    METHODS journal_with_one_call
      IMPORTING origin        TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS ltc_call_journal IMPLEMENTATION.

  METHOD given_origin_then_shown.
    MESSAGE e232(zatk) INTO DATA(from).

    DATA(text) = journal_with_one_call( `ZCL_ORDER_SERVICE=>CANCEL line 6` ).

    DATA(expected) = |ORDER_ID = '4711' { from } ZCL_ORDER_SERVICE=>CANCEL line 6|.
    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS expected )
                                      msg = `A recorded call shows where it came from` ).
  ENDMETHOD.


  METHOD given_no_origin_then_args_only.
    MESSAGE e232(zatk) INTO DATA(from).

    DATA(text) = journal_with_one_call( `` ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `(ORDER_ID = '4711')` AND text NS | { from } | )
                                      msg = `Without a known origin only the arguments are shown` ).
  ENDMETHOD.


  METHOD journal_with_one_call.
    DATA(get_order) = lcl_doubled_type=>describe( 'ZIF_ATK_TEST_ORDERS' )->find_method( 'GET_ORDER' ).
    DATA(arguments) = NEW lcl_arguments( ).
    arguments->put( name  = 'ORDER_ID'
                    value = NEW string( `4711` ) ).
    DATA(journal) = NEW lcl_call_journal( ).
    journal->record( doubled_method = get_order
                     arguments      = arguments
                     origin         = origin ).
    result = journal->describe_calls( get_order ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_call_site DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_asked_then_names_caller FOR TESTING.
    METHODS given_stack_then_code_tested FOR TESTING.
    METHODS given_direct_call_then_test FOR TESTING.
    METHODS given_only_machinery_empty FOR TESTING.
    METHODS given_no_line_then_name_only FOR TESTING.
    METHODS when_parsed_then_parts FOR TESTING.
    METHODS given_number_in_name_ignored FOR TESTING.
    METHODS given_number_anywhere_found FOR TESTING.
    METHODS given_own_frames_machinery FOR TESTING.
    METHODS given_framework_then_machinery FOR TESTING.

    METHODS origin_of
      IMPORTING frames        TYPE string_table
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS ltc_call_site IMPLEMENTATION.

  METHOD when_asked_then_names_caller.
    " needs the real call stack: off-stack the XCO stand-in has none (skipped in abap_transpile.json)
    DATA(origin) = lcl_call_site=>of_current_call( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( origin CS `ZCL_ATK=>WHEN_ASKED_THEN_NAMES_CALLER` )
                                      msg = |The origin must be this test method, not "{ origin }"| ).
  ENDMETHOD.


  METHOD given_stack_then_code_tested.
    " the stack while a double answers, innermost frame first, as XCO writes it for ADT
    DATA(frames) = VALUE string_table(
      ( `ZCL_ATK    frames [method] 4` )
      ( `ZCL_ATK    of_current_call [method] 2` )
      ( `ZCL_ATK    if_abap_testdouble_answer~answer [method] 9` )
      ( `CL_ATD_ANSWER_MAIN [system]    if_atd_answer~get_answer [method] 12` )
      ( `%_T00004S00000001O0000000002    zif_order_service~cancel [method] 3` )
      ( `ZCL_ORDER_SERVICE    zif_order_service~cancel [method] 6` )
      ( `ZCL_ORDER_SERVICE    when_cancelled_then_logged [method] 14` )
      ( `CL_AUNIT_TEST_CLASS [system]    invoke_test_method [method] 33` ) ).
    MESSAGE e234(zatk) WITH `6` INTO DATA(line).

    cl_abap_unit_assert=>assert_equals( act = origin_of( frames )
                                        exp = |ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL, { line }|
                                        msg = `The origin is the method of the code under test` ).
  ENDMETHOD.


  METHOD given_direct_call_then_test.
    " a test that calls the double itself is the origin, also inside ZCL_ATK's own test include
    DATA(frames) = VALUE string_table(
      ( `ZCL_ATK    frames [method] 4` )
      ( `ZCL_ATK    if_abap_testdouble_answer~answer [method] 9` )
      ( `ZCL_ATK    when_unwanted_names_caller [method] 3` )
      ( `CL_AUNIT_TEST_CLASS [system]    invoke_test_method [method] 33` ) ).
    MESSAGE e234(zatk) WITH `3` INTO DATA(line).

    cl_abap_unit_assert=>assert_equals( act = origin_of( frames )
                                        exp = |ZCL_ATK=>WHEN_UNWANTED_NAMES_CALLER, { line }|
                                        msg = `A test that calls the double directly is the origin` ).
  ENDMETHOD.


  METHOD given_only_machinery_empty.
    DATA(frames) = VALUE string_table(
      ( `ZCL_ATK    frames [method] 4` )
      ( `CL_AUNIT_TEST_CLASS [system]    invoke_test_method [method] 33` )
      ( `SAPLSABP_UNIT_SBOX [system]    _aunit_sbox_msg_x_test_method [function] 120` )
      ( `RS_AUNIT_SBOX_CLASS_TEST_INT [system]    start-of-selection [event] 8` ) ).

    cl_abap_unit_assert=>assert_initial( act = origin_of( frames )
                                         msg = `Without a frame of user code there is no origin` ).
  ENDMETHOD.


  METHOD given_no_line_then_name_only.
    DATA(frames) = VALUE string_table( ( `ZCL_ORDER_SERVICE    zif_order_service~cancel [method]` ) ).

    cl_abap_unit_assert=>assert_equals( act = origin_of( frames )
                                        exp = `ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL`
                                        msg = `Without a line number only the method is named` ).
  ENDMETHOD.


  METHOD when_parsed_then_parts.
    DATA(frame) = lcl_call_site=>parse( `CL_AUNIT_TEST_CLASS [system]    invoke_test_method [method] 33` ).

    cl_abap_unit_assert=>assert_equals( act = frame
                                        exp = VALUE lcl_call_site=>ty_frame( object    = `CL_AUNIT_TEST_CLASS`
                                                                             event     = `INVOKE_TEST_METHOD`
                                                                             line      = `33`
                                                                             is_system = abap_true )
                                        msg = `Object, event, line and the system marker are taken apart` ).
  ENDMETHOD.


  METHOD given_number_in_name_ignored.
    DATA(frame) = lcl_call_site=>parse( `ZCL_S4_SERVICE2    zif_s4_service2~get_v2 [method]` ).

    cl_abap_unit_assert=>assert_equals( act = frame-line
                                        exp = ``
                                        msg = `A digit inside a name is not a line number` ).
  ENDMETHOD.


  METHOD given_number_anywhere_found.
    " the format may put the line number before or after the event, with any spacing; the parser
    " takes the last number that stands on its own
    DATA(before_event) = lcl_call_site=>parse( `ZCL_S4_SERVICE2 (7)    get_v2 [method]` ).
    DATA(after_event) = lcl_call_site=>parse( `ZCL_S4_SERVICE2  get_v2 [method]  line 7` ).

    cl_abap_unit_assert=>assert_equals( act = before_event-line
                                        exp = `7`
                                        msg = `A line number next to the object is found` ).
    cl_abap_unit_assert=>assert_equals( act = after_event-line
                                        exp = `7`
                                        msg = `A line number after the event is found` ).
    cl_abap_unit_assert=>assert_equals( act = after_event-event
                                        exp = `GET_V2`
                                        msg = `The event follows the object whatever the spacing` ).
  ENDMETHOD.


  METHOD given_own_frames_machinery.
    DATA(own_frames) = VALUE string_table(
      ( `ZCL_ATK    frames [method] 4` )
      ( `ZCL_ATK    of_current_call [method] 2` )
      ( `ZCL_ATK    if_abap_testdouble_answer~answer [method] 9` )
      ( `ZCL_ATK    lcl_call_site=>frames [method] 4` )
      ( `ZCL_ATK    lcl_call_router->if_abap_testdouble_answer~answer [method] 9` ) ).

    LOOP AT own_frames INTO DATA(line).
      cl_abap_unit_assert=>assert_true( act = lcl_call_site=>is_machinery( lcl_call_site=>parse( line ) )
                                        msg = |ATK's own frame "{ line }" is not an origin| ).
    ENDLOOP.
    DATA(test_frame) = lcl_call_site=>parse( `ZCL_ATK    when_frames_are_read [method] 5` ).
    cl_abap_unit_assert=>assert_equals( act = lcl_call_site=>is_machinery( test_frame )
                                        exp = abap_false
                                        msg = `A test method of ZCL_ATK is an origin` ).
  ENDMETHOD.


  METHOD given_framework_then_machinery.
    DATA(framework_frames) = VALUE string_table(
      ( `CL_ATD_ANSWER_MAIN    if_atd_answer~get_answer [method] 12` )
      ( `CL_ABAP_TESTDOUBLE    configure_call [method] 5` )
      ( `%_T00004S00000001O0000000002    zif_order_service~cancel [method] 3` )
      ( `CL_AUNIT_TEST_CLASS [system]    invoke_test_method [method] 33` ) ).

    LOOP AT framework_frames INTO DATA(line).
      cl_abap_unit_assert=>assert_true( act = lcl_call_site=>is_machinery( lcl_call_site=>parse( line ) )
                                        msg = |The framework frame "{ line }" is not an origin| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD origin_of.
    result = lcl_call_site=>origin_in( frames ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_facade DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS when_dummy_then_instance_fits FOR TESTING.
    METHODS when_stub_then_instance_fits FOR TESTING.
    METHODS when_spy_then_instance_fits FOR TESTING.
    METHODS when_mock_then_instance_fits FOR TESTING.
    METHODS when_unknown_type_then_raises FOR TESTING.
    METHODS when_class_then_raises FOR TESTING.
    METHODS when_rule_matches_then_passes FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_facade IMPLEMENTATION.

  METHOD when_dummy_then_instance_fits.
    DATA(dummy) = zcl_atk=>dummy( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(instance) = dummy->instance( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( instance IS INSTANCE OF zif_atk_test_orders )
                                      msg = `The dummy must implement the doubled interface` ).
  ENDMETHOD.


  METHOD when_stub_then_instance_fits.
    DATA(stub) = zcl_atk=>stub( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(instance) = stub->instance( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( instance IS INSTANCE OF zif_atk_test_orders )
                                      msg = `The stub must implement the doubled interface` ).
  ENDMETHOD.


  METHOD when_spy_then_instance_fits.
    DATA(spy) = zcl_atk=>spy( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(instance) = spy->instance( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( instance IS INSTANCE OF zif_atk_test_orders )
                                      msg = `The spy must implement the doubled interface` ).
  ENDMETHOD.


  METHOD when_mock_then_instance_fits.
    DATA(mock) = zcl_atk=>mock( 'ZIF_ATK_TEST_ORDERS' ).

    DATA(instance) = mock->instance( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( instance IS INSTANCE OF zif_atk_test_orders )
                                      msg = `The mock must implement the doubled interface` ).
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


  METHOD when_class_then_raises.
    TRY.
        zcl_atk=>stub( 'ZCL_ATK' ).
        cl_abap_unit_assert=>fail( `A class must be rejected` ).
      CATCH zcx_atk INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->problem
                                            exp = zcx_atk=>not_an_interface
                                            msg = `Wrong problem for a class` ).
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
    METHODS when_placeholders_then_filled FOR TESTING.
    METHODS when_previous_then_kept FOR TESTING.
    METHODS when_text_then_what_fix_facts FOR TESTING.
    METHODS when_headline_then_what_only FOR TESTING.
    METHODS when_explanation_fix_and_facts FOR TESTING.
ENDCLASS.


CLASS ltc_exception_text IMPLEMENTATION.

  METHOD when_raised_then_text_has_fix.
    MESSAGE e102(zatk) WITH `ZCL_SAMPLE` INTO DATA(fix).

    DATA(error) = NEW zcx_atk( problem = zcx_atk=>not_an_interface context = VALUE #( value1 = `ZCL_SAMPLE` ) ).

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


  METHOD when_placeholders_then_filled.
    DATA(error) = NEW zcx_atk( problem = zcx_atk=>not_an_input
                               context = VALUE #( value1 = `SPLIT_NAME` value2 = `FIRST_NAME` value3 = `EXPORTING` ) ).

    DATA(text) = error->get_text( ).

    DATA(has_all) = xsdbool( text CS `SPLIT_NAME` AND text CS `FIRST_NAME` AND text CS `EXPORTING` ).
    cl_abap_unit_assert=>assert_true( act = has_all
                                      msg = `All three placeholders must appear in the text` ).
  ENDMETHOD.


  METHOD when_text_then_what_fix_facts.
    MESSAGE e006(zatk) WITH `ZIF_SAMPLE` `GO` INTO DATA(what).
    MESSAGE e104(zatk) INTO DATA(fix).
    DATA(error) = NEW zcx_atk( problem = zcx_atk=>unknown_method
                               context = VALUE #( value1 = `ZIF_SAMPLE` value2 = `GO` details = `Available: RUN.` ) ).

    DATA(text) = error->get_text( ).

    cl_abap_unit_assert=>assert_equals( act = text
                                        exp = |{ what } { fix } Available: RUN.|
                                        msg = `The text is what went wrong, the fix and the facts, in this order` ).
  ENDMETHOD.


  METHOD when_headline_then_what_only.
    MESSAGE e006(zatk) WITH `ZIF_SAMPLE` `GO` INTO DATA(what).
    DATA(error) = NEW zcx_atk( problem = zcx_atk=>unknown_method
                               context = VALUE #( value1 = `ZIF_SAMPLE` value2 = `GO` details = `Available: RUN.` ) ).

    DATA(headline) = error->headline( ).

    cl_abap_unit_assert=>assert_equals( act = headline
                                        exp = what
                                        msg = `The headline is what went wrong, the message of the failure` ).
  ENDMETHOD.


  METHOD when_explanation_fix_and_facts.
    MESSAGE e104(zatk) INTO DATA(fix).
    DATA(error) = NEW zcx_atk( problem = zcx_atk=>unknown_method
                               context = VALUE #( value1 = `ZIF_SAMPLE` value2 = `GO` details = `Available: RUN.` ) ).

    DATA(explanation) = error->explanation( ).

    cl_abap_unit_assert=>assert_equals( act = explanation
                                        exp = |{ fix } Available: RUN.|
                                        msg = `The explanation is the fix and the facts, the detail of the failure` ).
  ENDMETHOD.


  METHOD when_previous_then_kept.
    DATA(cause) = NEW zcx_atk_test_not_found( ).

    DATA(error) = NEW zcx_atk( problem = zcx_atk=>internal_error previous = cause ).

    cl_abap_unit_assert=>assert_equals( act = error->previous exp = cause msg = `The cause must stay reachable` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_arguments DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_no_values_then_any FOR TESTING.
    METHODS given_left_out_then_marked FOR TESTING.
    METHODS when_name_missing_then_not_met FOR TESTING.
    METHODS when_values_equal_then_met FOR TESTING.

    METHODS arguments_with
      IMPORTING name          TYPE abap_parmname
                value         TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_arguments.
ENDCLASS.


CLASS ltc_arguments IMPLEMENTATION.

  METHOD given_no_values_then_any.
    MESSAGE e206(zatk) INTO DATA(any).

    DATA(text) = NEW lcl_arguments( )->describe( ).

    cl_abap_unit_assert=>assert_equals( act = text exp = any msg = `No conditions means any arguments` ).
  ENDMETHOD.


  METHOD given_left_out_then_marked.
    MESSAGE e213(zatk) INTO DATA(not_supplied).
    DATA(arguments) = NEW lcl_arguments( ).
    arguments->put( name = 'SALUTATION' value = NEW string( ) is_supplied = abap_false ).

    DATA(text) = arguments->describe( ).

    cl_abap_unit_assert=>assert_equals( act = text
                                        exp = |SALUTATION = '' { not_supplied }|
                                        msg = `A parameter the caller left out must be marked` ).
  ENDMETHOD.


  METHOD when_name_missing_then_not_met.
    DATA(conditions) = arguments_with( name = 'ACTION' value = `CANCELLED` ).
    DATA(actual) = arguments_with( name = 'ORDER_ID' value = `4711` ).

    DATA(not_met) = conditions->names_not_met_by( actual ).

    cl_abap_unit_assert=>assert_equals( act = not_met
                                        exp = VALUE ty_texts( ( `ACTION` ) )
                                        msg = `A condition on an argument the call lacks is not met` ).
    cl_abap_unit_assert=>assert_equals( act = conditions->are_met_by( actual )
                                        exp = abap_false
                                        msg = `The conditions are not met` ).
  ENDMETHOD.


  METHOD when_values_equal_then_met.
    DATA(conditions) = arguments_with( name = 'ACTION' value = `CANCELLED` ).
    DATA(actual) = arguments_with( name = 'ACTION' value = `CANCELLED` ).

    cl_abap_unit_assert=>assert_true( act = conditions->are_met_by( actual ) msg = `Equal values meet the condition` ).
    cl_abap_unit_assert=>assert_initial( act = conditions->names_not_met_by( actual ) msg = `Nothing differs` ).
  ENDMETHOD.


  METHOD arguments_with.
    result = NEW #( ).
    result->put( name = name value = NEW string( value ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_name_hint DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_close_name_then_found FOR TESTING.
    METHODS given_far_name_then_nothing FOR TESTING.
    METHODS given_candidates_then_listed FOR TESTING.
ENDCLASS.


CLASS ltc_name_hint IMPLEMENTATION.

  METHOD given_close_name_then_found.
    DATA(closest) = lcl_name_hint=>closest( name       = `GET_ORDRE`
                                            candidates = VALUE #( ( `COUNT_OPEN` ) ( `GET_ORDER` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = closest
                                        exp = `GET_ORDER`
                                        msg = `The name a few typos away must be found` ).
  ENDMETHOD.


  METHOD given_far_name_then_nothing.
    DATA(closest) = lcl_name_hint=>closest( name       = `SOMETHING_ELSE`
                                            candidates = VALUE #( ( `COUNT_OPEN` ) ( `GET_ORDER` ) ) ).

    cl_abap_unit_assert=>assert_initial( act = closest msg = `A name far from every candidate gets no suggestion` ).
  ENDMETHOD.


  METHOD given_candidates_then_listed.
    DATA(text) = lcl_name_hint=>available( VALUE #( ( `COUNT_OPEN` ) ( `GET_ORDER` ) ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `COUNT_OPEN, GET_ORDER` )
                                      msg = `The candidates must be listed with commas` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_type_formatter DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_numc_then_name_and_shape FOR TESTING.
    METHODS given_packed_then_decimals FOR TESTING.
    METHODS given_string_then_plain FOR TESTING.
    METHODS given_object_ref_then_ref_to FOR TESTING.
    METHODS given_table_then_line_type FOR TESTING.
    METHODS given_structure_then_says_so FOR TESTING.

    METHODS parameter_type
      IMPORTING type_name      TYPE csequence
                method_name    TYPE csequence
                parameter_name TYPE csequence
      RETURNING VALUE(result)  TYPE string.
ENDCLASS.


CLASS ltc_type_formatter IMPLEMENTATION.

  METHOD given_numc_then_name_and_shape.
    DATA(text) = parameter_type( type_name      = 'ZIF_ATK_TEST_ORDERS'
                                 method_name    = 'GET_ORDER'
                                 parameter_name = 'ORDER_ID' ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `TY_ORDER_ID` AND text CS `N LENGTH 10` )
                                      msg = `A typed parameter shows its type name and its shape` ).
  ENDMETHOD.


  METHOD given_packed_then_decimals.
    DATA(text) = parameter_type( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'BOOK' parameter_name = 'AMOUNT' ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `P LENGTH 8 DECIMALS 2` )
                                      msg = `A packed number shows its length and decimals` ).
  ENDMETHOD.


  METHOD given_string_then_plain.
    DATA(text) = parameter_type( type_name      = 'ZIF_ATK_TEST_SHAPES'
                                 method_name    = 'SPLIT_NAME'
                                 parameter_name = 'FULL_NAME' ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `STRING` msg = `A built-in type shows its name once` ).
  ENDMETHOD.


  METHOD given_object_ref_then_ref_to.
    DATA(text) = parameter_type( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'NEW_LOG' parameter_name = 'RESULT' ).

    cl_abap_unit_assert=>assert_equals( act = text
                                        exp = `REF TO ZIF_ATK_TEST_AUDIT_LOG`
                                        msg = `An object reference shows the referenced type` ).
  ENDMETHOD.


  METHOD given_table_then_line_type.
    MESSAGE e231(zatk) WITH `STRING` INTO DATA(table_of_string).

    DATA(text) = parameter_type( type_name      = 'ZIF_ATK_TEST_SHAPES'
                                 method_name    = 'JOIN_NAMES'
                                 parameter_name = 'NAMES' ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS table_of_string )
                                      msg = `A table shows its line type` ).
  ENDMETHOD.


  METHOD given_structure_then_says_so.
    MESSAGE e228(zatk) INTO DATA(structure).

    DATA(text) = parameter_type( type_name = 'ZIF_ATK_TEST_SHAPES' method_name = 'SAVE' parameter_name = 'ORDER' ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( text CS `TY_ORDER` AND text CS structure )
                                      msg = `A structure shows its type name and that it is a structure` ).
  ENDMETHOD.


  METHOD parameter_type.
    DATA(owner) = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_name( type_name ) ).
    DATA(type) = owner->get_method_parameter_type( p_method_name    = CONV abap_methname( method_name )
                                                   p_parameter_name = CONV abap_parmname( parameter_name ) ).
    result = lcl_type_formatter=>describe( type ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_value_formatter DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS given_text_then_quoted FOR TESTING.
    METHODS given_numeric_text_then_quoted FOR TESTING.
    METHODS given_flag_then_quoted FOR TESTING.
    METHODS given_number_then_plain FOR TESTING.
    METHODS given_structure_then_parts FOR TESTING.
    METHODS given_table_then_row_count FOR TESTING.
    METHODS given_object_then_class_name FOR TESTING.
    METHODS given_initial_ref_then_says_so FOR TESTING.
    METHODS given_data_ref_then_says_so FOR TESTING.
    METHODS given_long_text_then_shortened FOR TESTING.
ENDCLASS.


CLASS ltc_value_formatter IMPLEMENTATION.

  METHOD given_text_then_quoted.
    DATA(text) = lcl_value_formatter=>format( `ACME` ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `'ACME'` msg = `Texts must be quoted` ).
  ENDMETHOD.


  METHOD given_numeric_text_then_quoted.
    DATA(text) = lcl_value_formatter=>format( CONV zif_atk_test_orders=>ty_order_id( '4711' ) ).

    cl_abap_unit_assert=>assert_equals( act = text
                                        exp = `'0000004711'`
                                        msg = `Numeric texts must show their full length` ).
  ENDMETHOD.


  METHOD given_flag_then_quoted.
    DATA(text) = lcl_value_formatter=>format( abap_true ).

    cl_abap_unit_assert=>assert_equals( act = text exp = `'X'` msg = `A one-character flag must be quoted` ).
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


  METHOD given_object_then_class_name.
    MESSAGE e210(zatk) WITH `ZCX_ATK_TEST_NOT_FOUND` INTO DATA(expected).

    DATA(text) = lcl_value_formatter=>format( NEW zcx_atk_test_not_found( ) ).

    cl_abap_unit_assert=>assert_equals( act = text exp = expected msg = `An object must show its class` ).
  ENDMETHOD.


  METHOD given_initial_ref_then_says_so.
    DATA no_object TYPE REF TO object.
    MESSAGE e211(zatk) INTO DATA(expected).

    DATA(text) = lcl_value_formatter=>format( no_object ).

    cl_abap_unit_assert=>assert_equals( act = text exp = expected msg = `An initial reference must say so` ).
  ENDMETHOD.


  METHOD given_data_ref_then_says_so.
    MESSAGE e212(zatk) INTO DATA(expected).
    DATA(number) = NEW i( 42 ).

    DATA(text) = lcl_value_formatter=>format( number ).

    cl_abap_unit_assert=>assert_equals( act = text exp = expected msg = `A data reference must say so` ).
  ENDMETHOD.


  METHOD given_long_text_then_shortened.
    DATA(long_text) = repeat( val = `x` occ = 500 ).

    DATA(text) = lcl_value_formatter=>format( long_text ).

    cl_abap_unit_assert=>assert_equals( act = strlen( text )
                                        exp = 203
                                        msg = `Long values must be cut at 200 characters` ).
  ENDMETHOD.

ENDCLASS.
