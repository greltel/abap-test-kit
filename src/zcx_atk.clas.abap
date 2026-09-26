"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: test double misuse or failed check</p>
"! Raised when a test double cannot be created or configured as written. Its text always says
"! what went wrong, how to fix it and then the facts involved: arguments, rules, the closest
"! call. Tests of ATK itself compare {@link zcx_atk.DATA:problem} with the constants of this
"! class to check which problem occurred.
CLASS zcx_atk DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.

    "! Between what went wrong, the fix and each fact. A blank, because the ABAP Unit view of
    "! ADT shows a failure on one line and prints a line break as #
    CONSTANTS part_separator TYPE string VALUE ` `.

    TYPES:
      "! A problem is a pair of messages in message class ZATK: what went wrong, how to fix it
      BEGIN OF ty_problem,
        what TYPE symsgno,
        fix  TYPE symsgno,
      END OF ty_problem.

    TYPES:
      "! Values for the placeholders &1 to &3 of both messages, plus details appended to the text
      BEGIN OF ty_context,
        value1  TYPE string,
        value2  TYPE string,
        value3  TYPE string,
        details TYPE string,
      END OF ty_context.

    CONSTANTS:
      "! Type &1 does not exist or is not active
      BEGIN OF unknown_type,
        what TYPE symsgno VALUE '001',
        fix  TYPE symsgno VALUE '101',
      END OF unknown_type.
    CONSTANTS:
      "! &1 is a data type, not an interface
      BEGIN OF not_an_object_type,
        what TYPE symsgno VALUE '002',
        fix  TYPE symsgno VALUE '101',
      END OF not_an_object_type.
    CONSTANTS:
      "! &1 is a class, and ATK doubles interfaces only
      BEGIN OF not_an_interface,
        what TYPE symsgno VALUE '003',
        fix  TYPE symsgno VALUE '102',
      END OF not_an_interface.
    CONSTANTS:
      "! &1 has no instance method &2 that a double can take over; did you mean &3?
      BEGIN OF unknown_method_did_you_mean,
        what TYPE symsgno VALUE '006',
        fix  TYPE symsgno VALUE '103',
      END OF unknown_method_did_you_mean.
    CONSTANTS:
      "! &1 has no instance method &2 that a double can take over; the details list the methods
      BEGIN OF unknown_method,
        what TYPE symsgno VALUE '006',
        fix  TYPE symsgno VALUE '104',
      END OF unknown_method.
    CONSTANTS:
      "! Method &1 has no parameter &2; did you mean &3?
      BEGIN OF unknown_param_did_you_mean,
        what TYPE symsgno VALUE '007',
        fix  TYPE symsgno VALUE '103',
      END OF unknown_param_did_you_mean.
    CONSTANTS:
      "! Method &1 has no parameter &2; the details list the parameters
      BEGIN OF unknown_parameter,
        what TYPE symsgno VALUE '007',
        fix  TYPE symsgno VALUE '104',
      END OF unknown_parameter.
    CONSTANTS:
      "! &2 of &1 is declared &3, not as an input
      BEGIN OF not_an_input,
        what TYPE symsgno VALUE '008',
        fix  TYPE symsgno VALUE '105',
      END OF not_an_input.
    CONSTANTS:
      "! &2 of &1 is declared &3, not as an output
      BEGIN OF not_an_output,
        what TYPE symsgno VALUE '009',
        fix  TYPE symsgno VALUE '106',
      END OF not_an_output.
    CONSTANTS:
      "! Method &1 has no RETURNING parameter
      BEGIN OF no_returning_parameter,
        what TYPE symsgno VALUE '010',
        fix  TYPE symsgno VALUE '107',
      END OF no_returning_parameter.
    CONSTANTS:
      "! Value &1 does not fit parameter &2 of type &3; the details say why
      BEGIN OF value_does_not_fit,
        what TYPE symsgno VALUE '011',
        fix  TYPE symsgno VALUE '108',
      END OF value_does_not_fit.
    CONSTANTS:
      "! &1 does not declare &2 in its RAISING clause; the details list the declared ones
      BEGIN OF undeclared_exception,
        what TYPE symsgno VALUE '012',
        fix  TYPE symsgno VALUE '109',
      END OF undeclared_exception.
    CONSTANTS:
      "! This rule for &1 already answers with &2
      BEGIN OF answer_already_set,
        what TYPE symsgno VALUE '013',
        fix  TYPE symsgno VALUE '110',
      END OF answer_already_set.
    CONSTANTS:
      "! Parameter &2 of &1 already has a value in this rule or check; the details show it
      BEGIN OF value_given_twice,
        what TYPE symsgno VALUE '014',
        fix  TYPE symsgno VALUE '111',
      END OF value_given_twice.
    CONSTANTS:
      "! times( ) of a mock needs 1 or more, but got &2
      BEGIN OF invalid_expected_calls,
        what TYPE symsgno VALUE '015',
        fix  TYPE symsgno VALUE '112',
      END OF invalid_expected_calls.
    CONSTANTS:
      "! times( ) of a spy needs 0 or more, but got &2
      BEGIN OF negative_expected_calls,
        what TYPE symsgno VALUE '016',
        fix  TYPE symsgno VALUE '113',
      END OF negative_expected_calls.
    CONSTANTS:
      "! raises( ) for &1 got no exception object
      BEGIN OF missing_exception,
        what TYPE symsgno VALUE '017',
        fix  TYPE symsgno VALUE '114',
      END OF missing_exception.
    CONSTANTS:
      "! ATDF could not create a double of &1; the details hold the text of ATDF
      BEGIN OF atdf_create_failed,
        what TYPE symsgno VALUE '018',
        fix  TYPE symsgno VALUE '115',
      END OF atdf_create_failed.
    CONSTANTS:
      "! ATDF could not take over method &1; the details hold the text of ATDF
      BEGIN OF atdf_route_failed,
        what TYPE symsgno VALUE '019',
        fix  TYPE symsgno VALUE '116',
      END OF atdf_route_failed.
    CONSTANTS:
      "! Dummy &1 was called: &2
      BEGIN OF dummy_called,
        what TYPE symsgno VALUE '020',
        fix  TYPE symsgno VALUE '117',
      END OF dummy_called.
    CONSTANTS:
      "! &1 was called with arguments that match none of its rules; the details show them
      BEGIN OF no_matching_rule,
        what TYPE symsgno VALUE '021',
        fix  TYPE symsgno VALUE '118',
      END OF no_matching_rule.
    CONSTANTS:
      "! &1 was called, but no expect_call( ) declares it
      BEGIN OF unexpected_call,
        what TYPE symsgno VALUE '022',
        fix  TYPE symsgno VALUE '119',
      END OF unexpected_call.
    CONSTANTS:
      "! &1 was called with arguments no expect_call( ) declares; the details show them
      BEGIN OF no_matching_expectation,
        what TYPE symsgno VALUE '026',
        fix  TYPE symsgno VALUE '123',
      END OF no_matching_expectation.
    CONSTANTS:
      "! &1: expected &2 matching call(s), but found &3
      BEGIN OF wrong_call_count,
        what TYPE symsgno VALUE '023',
        fix  TYPE symsgno VALUE '120',
      END OF wrong_call_count.
    CONSTANTS:
      "! &1 must not be called, but was called &2 time(s)
      BEGIN OF unwanted_call,
        what TYPE symsgno VALUE '024',
        fix  TYPE symsgno VALUE '121',
      END OF unwanted_call.
    CONSTANTS:
      "! ATK could not handle a call of &1; the details hold the cause
      BEGIN OF internal_error,
        what TYPE symsgno VALUE '025',
        fix  TYPE symsgno VALUE '116',
      END OF internal_error.

    "! Which problem occurred; one of the constants of this class
    DATA problem TYPE ty_problem READ-ONLY.
    "! Facts appended to the text, one sentence each, for example the arguments of the calls involved
    DATA details TYPE string READ-ONLY.

    "! Creates the exception for one of the problems defined as constants of this class.
    "! @parameter problem  | Which problem occurred, for example {@link .DATA:unknown_type}
    "! @parameter context  | Placeholder values and details for the message
    "! @parameter previous | The exception that caused this one, if any
    METHODS constructor
      IMPORTING problem  TYPE ty_problem
                context  TYPE ty_context      OPTIONAL
                previous TYPE REF TO cx_root OPTIONAL.

    "! What went wrong, in one sentence: the message of an ABAP Unit failure.
    "! @parameter result | The first part of the text
    METHODS headline
      RETURNING VALUE(result) TYPE string.

    "! How to fix it, followed by the facts: the detail of an ABAP Unit failure.
    "! @parameter result | The second and third part of the text
    METHODS explanation
      RETURNING VALUE(result) TYPE string.

    " the text is the headline followed by the explanation
    METHODS if_message~get_text REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS message_class TYPE symsgid VALUE 'ZATK'.
    CONSTANTS error_message TYPE symsgty VALUE 'E'.

    CONSTANTS: BEGIN OF placeholder,
                 first  TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV1',
                 second TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV2',
                 third  TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV3',
               END OF placeholder.

    "! The message with the placeholders of this exception filled in
    METHODS message_text
      IMPORTING number        TYPE symsgno
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcx_atk IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->problem = problem.
    details = context-details.
    if_t100_dyn_msg~msgty = error_message.
    if_t100_dyn_msg~msgv1 = context-value1.
    if_t100_dyn_msg~msgv2 = context-value2.
    if_t100_dyn_msg~msgv3 = context-value3.
    if_t100_message~t100key = VALUE #( msgid = message_class
                                       msgno = problem-what
                                       attr1 = placeholder-first
                                       attr2 = placeholder-second
                                       attr3 = placeholder-third ).
  ENDMETHOD.


  METHOD headline.
    result = message_text( problem-what ).
  ENDMETHOD.


  METHOD explanation.
    result = message_text( problem-fix ).
    IF details IS NOT INITIAL.
      result = |{ result }{ part_separator }{ details }|.
    ENDIF.
  ENDMETHOD.


  METHOD if_message~get_text.
    result = |{ headline( ) }{ part_separator }{ explanation( ) }|.
  ENDMETHOD.


  METHOD message_text.
    MESSAGE ID message_class TYPE error_message NUMBER number
            WITH if_t100_dyn_msg~msgv1 if_t100_dyn_msg~msgv2 if_t100_dyn_msg~msgv3
            INTO result.
  ENDMETHOD.

ENDCLASS.


