CLASS lcl_arguments DEFINITION DEFERRED.
CLASS lcl_doubled_method DEFINITION DEFERRED.
CLASS lcl_doubled_type DEFINITION DEFERRED.
CLASS lcl_call_journal DEFINITION DEFERRED.
CLASS lcl_call_rule DEFINITION DEFERRED.
CLASS lcl_call_router DEFINITION DEFERRED.

TYPES ty_texts TYPE STANDARD TABLE OF string WITH EMPTY KEY.

"! Kinds of test double. They differ only in how they react to calls without a matching rule.
INTERFACE lif_role.
  TYPES:
    BEGIN OF ENUM ty_role,
      dummy,
      stub,
      spy,
      mock,
    END OF ENUM ty_role.
ENDINTERFACE.

"! Where failures go: the running ABAP Unit test, or a recorder in ATK's own tests.
INTERFACE lif_failure_reporter.
  "! Records the failure and lets the code under test continue, so that a CATCH in the code
  "! under test cannot hide it.
  METHODS report_during_act
    IMPORTING failure TYPE REF TO zcx_atk.

  "! Records the failure and ends the current test method.
  METHODS report_verification
    IMPORTING failure TYPE REF TO zcx_atk.
ENDINTERFACE.

"! The only door to CL_ABAP_TESTDOUBLE.
INTERFACE lif_atdf_gateway.
  "! Creates the ATDF double of the type.
  METHODS create_double
    IMPORTING doubled_type  TYPE REF TO lcl_doubled_type
    RETURNING VALUE(result) TYPE REF TO object.

  "! Sends every call of every method of the double to the answer.
  METHODS route_calls
    IMPORTING double       TYPE REF TO object
              doubled_type TYPE REF TO lcl_doubled_type
              answer       TYPE REF TO if_abap_testdouble_answer.
ENDINTERFACE.


"! Small text helpers for failure details.
CLASS lcl_text DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! Joins texts with a comma, for lists of names and arguments.
    CLASS-METHODS join
      IMPORTING texts         TYPE ty_texts
      RETURNING VALUE(result) TYPE string.

    "! Joins the sentences of the details of a failure, the way ZCX_ATK joins its parts.
    CLASS-METHODS sentences
      IMPORTING texts         TYPE ty_texts
      RETURNING VALUE(result) TYPE string.

    "! "Label: a, b." - one line of the details of a failure.
    CLASS-METHODS labeled
      IMPORTING label         TYPE string
                text          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


"! Readable type descriptions for messages: TY_ORDER_ID (N LENGTH 10), REF TO ZIF_LOG, table of STRING.
CLASS lcl_type_formatter DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS describe
      IMPORTING type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(result) TYPE string.

    "! What kind of value the type holds, in words: single value, structure, table, reference.
    CLASS-METHODS kind_word
      IMPORTING type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS technical_name
      IMPORTING type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS elementary_name
      IMPORTING type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS referenced_name
      IMPORTING type          TYPE REF TO cl_abap_refdescr
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS lcl_value_formatter DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS format
      IMPORTING value         TYPE any
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    CONSTANTS max_length TYPE i VALUE 200.

    CLASS-METHODS format_elementary
      IMPORTING value         TYPE any
                type_kind     TYPE abap_typekind
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS format_structure
      IMPORTING value         TYPE any
                description   TYPE REF TO cl_abap_structdescr
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS format_table
      IMPORTING value         TYPE any
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS format_reference
      IMPORTING value         TYPE any
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS shorten
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS lcl_name_hint DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! The candidate that is at most a few typos away from the name, or nothing.
    CLASS-METHODS closest
      IMPORTING name          TYPE string
                candidates    TYPE ty_texts
      RETURNING VALUE(result) TYPE string.

    "! "Available: A, B, C." for the details of a failure.
    CLASS-METHODS available
      IMPORTING candidates    TYPE ty_texts
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    CONSTANTS max_typos TYPE i VALUE 3.
ENDCLASS.


"! Where a call of a double came from: the method of the code under test and the line within
"! it, read from the XCO call stack while the double answers (CL_ABAP_GET_CALL_STACK is not
"! permitted in ABAP for Cloud Development). The ADT format of XCO writes one line per frame,
"! innermost first: "ZCL_ORDER_SERVICE    zif_order_service~cancel [method]" with the line number
"! of the include flavor, and "[system]" after the object of a system frame.
CLASS lcl_call_site DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_frame,
        object    TYPE string,
        event     TYPE string,
        line      TYPE string,
        is_system TYPE abap_bool,
      END OF ty_frame.

    "! "ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL, line 6 of the method" - the frame of the
    "! current call stack that belongs neither to ATK nor to the test double framework
    CLASS-METHODS of_current_call
      RETURNING VALUE(result) TYPE string.

    "! The origin in the given stack lines (ADT format, innermost frame first): the first frame
    "! that is neither ATK, nor SAP, nor the test double framework. Empty when there is none.
    CLASS-METHODS origin_in
      IMPORTING frames        TYPE string_table
      RETURNING VALUE(result) TYPE string.

    "! One line of the ADT format of the XCO call stack, taken apart: the first word is the object,
    "! the next word that is not the system marker is the event, and the line number is the last
    "! number that stands on its own, wherever the format puts it.
    CLASS-METHODS parse
      IMPORTING line          TYPE string
      RETURNING VALUE(result) TYPE ty_frame.

    "! Frames of ATK itself, of SAP and of the test double framework are not the origin.
    CLASS-METHODS is_machinery
      IMPORTING frame         TYPE ty_frame
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS system_marker TYPE string VALUE `[system]`.
    CONSTANTS standalone_number TYPE string VALUE `(?<!\w)\d+(?!\w)`.
    CONSTANTS:
      "! ATK's own frames between the double and the stack, with or without their local class in
      "! front of the method name; other frames of ZCL_ATK are its tests
      BEGIN OF own,
        class_name TYPE string VALUE `ZCL_ATK`,
        stack      TYPE string VALUE `*FRAMES`,
        origin     TYPE string VALUE `*OF_CURRENT_CALL`,
        answer     TYPE string VALUE `*IF_ABAP_TESTDOUBLE_ANSWER~ANSWER`,
      END OF own,
      "! The test double framework: its classes, the generated doubles and the facade
      BEGIN OF framework,
        classes   TYPE string VALUE `CL_ATD*`,
        generated TYPE string VALUE `%_*`,
        facade    TYPE string VALUE `CL_ABAP_TESTDOUBLE*`,
      END OF framework.

    "! The current call stack as XCO writes it for ADT; line numbers of the include flavor,
    "! which counts from the METHOD statement (cheap; the source flavor scans the source)
    CLASS-METHODS frames
      RETURNING VALUE(result) TYPE string_table.

    CLASS-METHODS describe
      IMPORTING frame         TYPE ty_frame
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


"! Copies a value into a data object of another type, but only when nothing is lost on the way.
CLASS lcl_value_conversion DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! Copies the source into the target and tells whether the target now holds exactly the
    "! source value. Conversion errors are handled here, never in a comparison, because ABAP
    "! cannot catch a conversion error that happens inside a comparison.
    CLASS-METHODS copies_losslessly
      IMPORTING source        TYPE any
                target        TYPE REF TO data
      RETURNING VALUE(result) TYPE abap_bool.

    "! Why the source does not fit the target: the kinds differ, the type differs, the
    "! conversion fails, or the target would hold a different value.
    CLASS-METHODS explain_misfit
      IMPORTING source        TYPE any
                target        TYPE REF TO data
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS copy
      IMPORTING source TYPE any
                target TYPE REF TO data
      RAISING   cx_sy_conversion_error
                cx_sy_move_cast_error
                cx_sy_itab_error.

    CLASS-METHODS explain_kind_mismatch
      IMPORTING source        TYPE any
                target_type   TYPE REF TO cl_abap_datadescr
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS explain_copy
      IMPORTING source        TYPE any
                target        TYPE REF TO data
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS fits_structurally
      IMPORTING source        TYPE any
                target_type   TYPE REF TO cl_abap_datadescr
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS has_same_line_type
      IMPORTING source_type   TYPE REF TO cl_abap_typedescr
                target_type   TYPE REF TO cl_abap_datadescr
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS is_same_value
      IMPORTING source        TYPE any
                target        TYPE any
      RETURNING VALUE(result) TYPE abap_bool
      RAISING   cx_sy_conversion_error.

    "! Numbers and numeric text (type N): compared with text, ABAP converts the text to a number.
    CLASS-METHODS is_numeric
      IMPORTING type_kind     TYPE abap_typekind
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS is_text
      IMPORTING type_kind     TYPE abap_typekind
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.


"! Named values of method parameters: the arguments of a recorded call, or the conditions of a
"! rule or check. As conditions they are met when every named value equals the actual one.
CLASS lcl_arguments DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_argument,
        name        TYPE abap_parmname,
        value       TYPE REF TO data,
        "! abap_false for an optional parameter the caller left out; its value is then initial
        is_supplied TYPE abap_bool,
      END OF ty_argument.
    "! In the order the values were put, which is the order of the parameters of the method
    TYPES ty_arguments TYPE STANDARD TABLE OF ty_argument WITH EMPTY KEY.

    METHODS put
      IMPORTING name        TYPE abap_parmname
                value       TYPE REF TO data
                is_supplied TYPE abap_bool DEFAULT abap_true.

    METHODS has
      IMPORTING name          TYPE abap_parmname
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS value_of
      IMPORTING name          TYPE abap_parmname
      RETURNING VALUE(result) TYPE REF TO data.

    METHODS entries
      RETURNING VALUE(result) TYPE ty_arguments.

    METHODS size
      RETURNING VALUE(result) TYPE i.

    METHODS are_met_by
      IMPORTING actual        TYPE REF TO lcl_arguments
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS names_not_met_by
      IMPORTING actual        TYPE REF TO lcl_arguments
      RETURNING VALUE(result) TYPE ty_texts.

    METHODS describe
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    DATA named_values TYPE ty_arguments.

    METHODS is_met_by
      IMPORTING expected      TYPE ty_argument
                actual        TYPE REF TO lcl_arguments
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS describe_argument
      IMPORTING argument      TYPE ty_argument
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


"! One method of the doubled type, described with RTTI: its parameters, their kinds and types,
"! and the exceptions it declares. Knows how to turn test values into parameter values.
CLASS lcl_doubled_method DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_parameter,
        name        TYPE abap_parmname,
        kind        TYPE abap_parmkind,
        is_optional TYPE abap_bool,
        data_type   TYPE REF TO cl_abap_datadescr,
      END OF ty_parameter.
    "! In the order of the declaration, so that lists in messages read like the signature
    TYPES ty_parameters TYPE STANDARD TABLE OF ty_parameter WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_naming,
        "! Name the test uses, for example GET_ORDER or ZIF_BASE~GET_ORDER
        name      TYPE string,
        "! Name a dynamic call on the ATDF double needs, for example ZIF_ORDERS~GET_ORDER
        call_name TYPE string,
      END OF ty_naming.

    METHODS constructor
      IMPORTING owner       TYPE REF TO cl_abap_objectdescr
                description TYPE abap_methdescr
                naming      TYPE ty_naming.

    METHODS name
      RETURNING VALUE(result) TYPE string.

    METHODS call_name
      RETURNING VALUE(result) TYPE string.

    "! Adds a condition on an IMPORTING or CHANGING parameter.
    METHODS add_input
      IMPORTING arguments      TYPE REF TO lcl_arguments
                parameter_name TYPE csequence
                value          TYPE any.

    "! Adds a value for an EXPORTING or CHANGING parameter.
    METHODS add_output
      IMPORTING arguments      TYPE REF TO lcl_arguments
                parameter_name TYPE csequence
                value          TYPE any.

    METHODS returning_value
      IMPORTING value         TYPE any
      RETURNING VALUE(result) TYPE REF TO data.

    METHODS kind_of
      IMPORTING parameter_name TYPE abap_parmname
      RETURNING VALUE(result)  TYPE abap_parmkind.

    METHODS check_declares
      IMPORTING exception TYPE REF TO cx_root.

    "! Arguments for the recording call that binds the ATDF configuration to this method:
    "! every mandatory input gets a value of its type.
    METHODS recording_arguments
      RETURNING VALUE(result) TYPE abap_parmbind_tab.

    "! Copies of the input arguments of a call the ATDF double received. An optional parameter
    "! the caller left out is recorded as not supplied, with an initial value.
    METHODS read_arguments
      IMPORTING atdf_arguments TYPE REF TO if_abap_testdouble_arguments
      RETURNING VALUE(result)  TYPE REF TO lcl_arguments.

  PRIVATE SECTION.
    CONSTANTS no_check_root TYPE string VALUE `CX_NO_CHECK`.
    CONSTANTS: BEGIN OF keyword,
                 importing TYPE string VALUE `IMPORTING`,
                 exporting TYPE string VALUE `EXPORTING`,
                 changing  TYPE string VALUE `CHANGING`,
                 returning TYPE string VALUE `RETURNING`,
               END OF keyword.
    CONSTANTS: BEGIN OF generic_fallback,
                 text_length   TYPE i VALUE 1,
                 packed_length TYPE i VALUE 8,
                 decimals      TYPE i VALUE 0,
               END OF generic_fallback.

    DATA method_naming TYPE ty_naming.
    DATA parameter_list TYPE ty_parameters.
    DATA declared_exceptions TYPE abap_excpdescr_tab.

    METHODS find_parameter
      IMPORTING parameter_name TYPE csequence
      RETURNING VALUE(result)  TYPE ty_parameter.

    METHODS raise_unknown_parameter
      IMPORTING parameter_name TYPE string.

    "! "ORDER_ID (IMPORTING), RESULT (RETURNING)" - the parameters with their kinds
    METHODS parameter_names
      RETURNING VALUE(result) TYPE ty_texts.

    "! "Outputs: A, B." or the hint that the method has none, for returns( ) on the wrong method
    METHODS describe_outputs
      RETURNING VALUE(result) TYPE string.

    METHODS describe_declared_exceptions
      RETURNING VALUE(result) TYPE string.

    METHODS add_argument
      IMPORTING arguments TYPE REF TO lcl_arguments
                parameter TYPE ty_parameter
                value     TYPE any.

    METHODS to_value
      IMPORTING parameter     TYPE ty_parameter
                value         TYPE any
      RETURNING VALUE(result) TYPE REF TO data.

    METHODS read_argument
      IMPORTING atdf_arguments TYPE REF TO if_abap_testdouble_arguments
                parameter      TYPE ty_parameter
      RETURNING VALUE(result)  TYPE lcl_arguments=>ty_argument.

    "! Whether the caller passed the parameter; a mandatory parameter is always supplied.
    METHODS is_supplied
      IMPORTING atdf_arguments TYPE REF TO if_abap_testdouble_arguments
                parameter      TYPE ty_parameter
      RETURNING VALUE(result)  TYPE abap_bool
      RAISING   cx_static_check.

    CLASS-METHODS parameter_type
      IMPORTING owner          TYPE REF TO cl_abap_objectdescr
                method_name    TYPE abap_methname
                parameter_name TYPE abap_parmname
      RETURNING VALUE(result)  TYPE REF TO cl_abap_datadescr.

    CLASS-METHODS new_value_for
      IMPORTING parameter     TYPE ty_parameter
                template      TYPE any
      RETURNING VALUE(result) TYPE REF TO data.

    CLASS-METHODS placeholder_for
      IMPORTING data_type     TYPE REF TO cl_abap_datadescr
      RETURNING VALUE(result) TYPE REF TO data.

    CLASS-METHODS concrete_type_for
      IMPORTING data_type     TYPE REF TO cl_abap_datadescr
      RETURNING VALUE(result) TYPE REF TO cl_abap_datadescr.

    CLASS-METHODS copy_of
      IMPORTING source        TYPE REF TO data
                parameter     TYPE ty_parameter
      RETURNING VALUE(result) TYPE REF TO data.

    CLASS-METHODS type_name_of
      IMPORTING parameter     TYPE ty_parameter
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS kind_name
      IMPORTING kind          TYPE abap_parmkind
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS super_class_of
      IMPORTING class_type    TYPE REF TO cl_abap_classdescr
      RETURNING VALUE(result) TYPE REF TO cl_abap_classdescr.
ENDCLASS.


"! The interface being doubled, described with RTTI.
CLASS lcl_doubled_type DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES ty_methods TYPE STANDARD TABLE OF REF TO lcl_doubled_method WITH EMPTY KEY.

    "! Describes a global interface; anything else is rejected with the reason.
    CLASS-METHODS describe
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_type.

    METHODS constructor
      IMPORTING description TYPE REF TO cl_abap_objectdescr
                type_name   TYPE string.

    METHODS name
      RETURNING VALUE(result) TYPE string.

    "! The methods a double can take over.
    METHODS doubled_methods
      RETURNING VALUE(result) TYPE ty_methods.

    "! The method the test names; raises ZCX_ATK with a hint for unknown names.
    METHODS find_method
      IMPORTING method_name   TYPE csequence
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_method.

    "! The method ATDF reports as called, with or without the interface prefix.
    METHODS method_called_by_atdf
      IMPORTING atdf_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_method.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_catalog_entry,
        name           TYPE string,
        doubled_method TYPE REF TO lcl_doubled_method,
      END OF ty_catalog_entry.
    TYPES ty_catalog TYPE SORTED TABLE OF ty_catalog_entry WITH UNIQUE KEY name.

    CONSTANTS component_separator TYPE string VALUE `~`.

    DATA doubled_type_name TYPE string.
    DATA catalog TYPE ty_catalog.

    METHODS add_methods_of
      IMPORTING owner  TYPE REF TO cl_abap_objectdescr
                prefix TYPE string.

    METHODS add_component_interfaces
      IMPORTING description TYPE REF TO cl_abap_objectdescr.

    METHODS call_name_of
      IMPORTING method_name   TYPE string
      RETURNING VALUE(result) TYPE string.

    METHODS lookup
      IMPORTING method_name   TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_method.

    METHODS raise_unknown_method
      IMPORTING method_name TYPE string.

    CLASS-METHODS is_configurable
      IMPORTING description   TYPE abap_methdescr
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.


"! Every call a double received, in order.
CLASS lcl_call_journal DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_call,
        called_method TYPE REF TO lcl_doubled_method,
        arguments     TYPE REF TO lcl_arguments,
        "! Method and line of the code under test that made the call, if known
        origin        TYPE string,
      END OF ty_call.
    TYPES ty_calls TYPE STANDARD TABLE OF ty_call WITH EMPTY KEY.

    METHODS record
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                arguments      TYPE REF TO lcl_arguments
                origin         TYPE string OPTIONAL.

    "! "ORDER_ID = '0000004711' from ZCL_ORDER_SERVICE=>CANCEL line 6" - the arguments of a
    "! call and, when known, where it came from
    CLASS-METHODS describe_call
      IMPORTING call          TYPE ty_call
      RETURNING VALUE(result) TYPE string.

    METHODS calls_to
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
      RETURNING VALUE(result)  TYPE ty_calls.

    METHODS count_matching
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                filter         TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE i.

    "! Why the number of matching calls is not the expected one: the expected arguments, then
    "! the matching calls, or the closest call and where it differs, or that no call was recorded.
    METHODS explain_count
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                filter         TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE string.

    METHODS describe_calls
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
      RETURNING VALUE(result)  TYPE string.

  PRIVATE SECTION.
    DATA calls TYPE ty_calls.

    METHODS closest_call
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                filter         TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE ty_call.

    METHODS describe_matching_calls
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                filter         TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE string.

    METHODS describe_closest_call
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                filter         TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE string.
ENDCLASS.


"! A rule of a stub or spy, or an expectation of a mock: the calls it applies to, and the answer.
CLASS lcl_call_rule DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_atk_call_rule.
    INTERFACES zif_atk_call_expectation.

    "! @parameter is_expectation | abap_true for expect_call( ): the rule counts its calls
    METHODS constructor
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                sequence       TYPE i
                is_expectation TYPE abap_bool.

    METHODS is_for
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
      RETURNING VALUE(result)  TYPE abap_bool.

    METHODS applies_to
      IMPORTING arguments     TYPE REF TO lcl_arguments
      RETURNING VALUE(result) TYPE abap_bool.

    "! More with( ) conditions win. On a tie an expectation that still waits for calls wins
    "! over one that got all its calls, so two identical expect_call( ) expect two calls;
    "! on a full tie the rule written later wins.
    METHODS outranks
      IMPORTING other         TYPE REF TO lcl_call_rule
      RETURNING VALUE(result) TYPE abap_bool.

    "! A rule of a stub or spy is always open; an expectation until it got all its calls.
    METHODS is_open
      RETURNING VALUE(result) TYPE abap_bool.

    "! "(ORDER_ID = '0000004711')" - the with( ) conditions, for lists of rules in messages
    METHODS describe_conditions
      RETURNING VALUE(result) TYPE string.

    "! Names of the with( ) conditions these arguments do not meet
    METHODS unmet_conditions
      IMPORTING arguments     TYPE REF TO lcl_arguments
      RETURNING VALUE(result) TYPE ty_texts.

    METHODS answer
      IMPORTING atdf_result TYPE REF TO if_abap_testdouble_result.

    METHODS is_satisfied
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS unmet_expectation
      IMPORTING journal       TYPE REF TO lcl_call_journal
      RETURNING VALUE(result) TYPE REF TO zcx_atk.

  PRIVATE SECTION.
    DATA doubled_method TYPE REF TO lcl_doubled_method.
    DATA rule_sequence TYPE i.
    DATA counts_calls TYPE abap_bool.
    DATA conditions TYPE REF TO lcl_arguments.
    DATA outputs TYPE REF TO lcl_arguments.
    DATA returning_value TYPE REF TO data.
    DATA exception_to_raise TYPE REF TO cx_root.
    DATA expected_calls TYPE i VALUE 1.
    DATA call_count TYPE i.

    METHODS add_condition
      IMPORTING parameter TYPE csequence
                value     TYPE any.

    METHODS add_output
      IMPORTING parameter TYPE csequence
                value     TYPE any.

    METHODS set_returning
      IMPORTING value TYPE any.

    METHODS set_exception
      IMPORTING exception TYPE REF TO cx_root.

    METHODS ensure_no_exception.

    "! @parameter answer | The answer the rule already has: returns( ), sets( ) or raises( )
    METHODS raise_answer_already_set
      IMPORTING answer TYPE string.

    METHODS write_outputs
      IMPORTING atdf_result TYPE REF TO if_abap_testdouble_result
      RAISING   cx_static_check.
ENDCLASS.


"! All rules of one double.
CLASS lcl_rulebook DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_rules TYPE STANDARD TABLE OF REF TO lcl_call_rule WITH EMPTY KEY.

    "! @parameter is_expectation | abap_true for a mock: the rule counts its calls
    METHODS new_rule
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                is_expectation TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result)  TYPE REF TO lcl_call_rule.

    METHODS best_rule
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                arguments      TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE REF TO lcl_call_rule.

    METHODS has_rules_for
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
      RETURNING VALUE(result)  TYPE abap_bool.

    METHODS rules
      RETURNING VALUE(result) TYPE ty_rules.

    "! The rules of the method and where the closest one differs from the arguments, for
    "! the failure of a call no rule matches.
    "! @parameter list_label    | "Rules:" or "Expectations:"
    "! @parameter closest_label | "Closest rule differs in:" or its expectation counterpart
    METHODS explain_no_match
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                arguments      TYPE REF TO lcl_arguments
                list_label     TYPE string
                closest_label  TYPE string
      RETURNING VALUE(result)  TYPE string.

  PRIVATE SECTION.
    DATA all_rules TYPE ty_rules.

    METHODS rules_for
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
      RETURNING VALUE(result)  TYPE ty_rules.
ENDCLASS.


CLASS lcl_call_verification DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_atk_call_verification.

    METHODS constructor
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                journal        TYPE REF TO lcl_call_journal
                reporter       TYPE REF TO lif_failure_reporter.

  PRIVATE SECTION.
    DATA doubled_method TYPE REF TO lcl_doubled_method.
    DATA recorded_calls TYPE REF TO lcl_call_journal.
    DATA failure_reporter TYPE REF TO lif_failure_reporter.
    DATA conditions TYPE REF TO lcl_arguments.
ENDCLASS.


"! The ATDF answer of a double: records every call and answers it by the best rule.
CLASS lcl_call_router DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES if_abap_testdouble_answer.

    METHODS constructor
      IMPORTING doubled_type TYPE REF TO lcl_doubled_type
                role         TYPE lif_role=>ty_role
                reporter     TYPE REF TO lif_failure_reporter.

    METHODS doubled_type
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_type.

    METHODS rulebook
      RETURNING VALUE(result) TYPE REF TO lcl_rulebook.

    METHODS journal
      RETURNING VALUE(result) TYPE REF TO lcl_call_journal.

    METHODS reporter
      RETURNING VALUE(result) TYPE REF TO lif_failure_reporter.

  PRIVATE SECTION.
    DATA described_type TYPE REF TO lcl_doubled_type.
    DATA double_role TYPE lif_role=>ty_role.
    DATA failure_reporter TYPE REF TO lif_failure_reporter.
    DATA call_rules TYPE REF TO lcl_rulebook.
    DATA recorded_calls TYPE REF TO lcl_call_journal.

    METHODS respond
      IMPORTING call        TYPE lcl_call_journal=>ty_call
                atdf_result TYPE REF TO if_abap_testdouble_result.

    "! @parameter explanation | The rules or expectations that exist, for a call none matches
    METHODS failure_for
      IMPORTING problem       TYPE zcx_atk=>ty_problem
                call          TYPE lcl_call_journal=>ty_call
                explanation   TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE REF TO zcx_atk.

    "! The rules or expectations of the method and where the closest one differs
    METHODS explain_no_match
      IMPORTING doubled_method TYPE REF TO lcl_doubled_method
                arguments      TYPE REF TO lcl_arguments
      RETURNING VALUE(result)  TYPE string.
ENDCLASS.


"! What the test holds: one object that plays dummy, stub, spy or mock.
CLASS lcl_double DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_atk_dummy.
    INTERFACES zif_atk_spy.
    INTERFACES zif_atk_mock.

    METHODS constructor
      IMPORTING router   TYPE REF TO lcl_call_router
                instance TYPE REF TO object.

  PRIVATE SECTION.
    DATA call_router TYPE REF TO lcl_call_router.
    DATA fake TYPE REF TO object.

    METHODS find_method
      IMPORTING method_name   TYPE csequence
      RETURNING VALUE(result) TYPE REF TO lcl_doubled_method.
ENDCLASS.


CLASS lcl_unit_failure_reporter DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_failure_reporter.
ENDCLASS.


"! The only door to CL_ABAP_TESTDOUBLE. FOR TESTING because it uses a test class; it lives in
"! this include, not in the test include, because ZCL_ATK itself needs it.
CLASS lth_atdf_gateway DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES lif_atdf_gateway.

  PRIVATE SECTION.
    "! ATDF applies a configuration to a limited number of calls; the router has to see all
    CONSTANTS unlimited_calls TYPE i VALUE 2147483647.

    " not named DOUBLE: the transpiler that runs the tests in CI cannot call a dynamic method
    " on a variable of that name
    METHODS route_method
      IMPORTING atdf_double    TYPE REF TO object
                doubled_method TYPE REF TO lcl_doubled_method
                answer         TYPE REF TO if_abap_testdouble_answer.
ENDCLASS.


"! Wires a double together. ZCL_ATK uses the standard wiring, ATK's own tests their own.
"! FOR TESTING because it creates the ATDF gateway.
CLASS lth_double_factory DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS standard
      RETURNING VALUE(result) TYPE REF TO lth_double_factory.

    METHODS constructor
      IMPORTING reporter TYPE REF TO lif_failure_reporter
                gateway  TYPE REF TO lif_atdf_gateway.

    METHODS create
      IMPORTING type_name     TYPE csequence
                role          TYPE lif_role=>ty_role
      RETURNING VALUE(result) TYPE REF TO lcl_double.

  PRIVATE SECTION.
    DATA failure_reporter TYPE REF TO lif_failure_reporter.
    DATA atdf_gateway TYPE REF TO lif_atdf_gateway.
ENDCLASS.


CLASS lcl_text IMPLEMENTATION.

  METHOD join.
    result = concat_lines_of( table = texts
                              sep   = `, ` ).
  ENDMETHOD.


  METHOD sentences.
    result = concat_lines_of( table = texts
                              sep   = zcx_atk=>part_separator ).
  ENDMETHOD.


  METHOD labeled.
    result = |{ label } { text }.|.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_type_formatter IMPLEMENTATION.

  METHOD describe.
    IF type IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(name) = type->get_relative_name( ).
    DATA(technical) = technical_name( type ).
    DATA(is_reference) = xsdbool( type->kind = cl_abap_typedescr=>kind_ref ).
    result = COND #( WHEN name IS INITIAL OR name = technical OR is_reference = abap_true
                     THEN technical
                     ELSE |{ name } ({ technical })| ).
  ENDMETHOD.


  METHOD kind_word.
    CASE type->kind.
      WHEN cl_abap_typedescr=>kind_struct.
        MESSAGE e228(zatk) INTO result.
      WHEN cl_abap_typedescr=>kind_table.
        MESSAGE e229(zatk) INTO result.
      WHEN cl_abap_typedescr=>kind_ref.
        MESSAGE e230(zatk) INTO result.
      WHEN OTHERS.
        MESSAGE e227(zatk) INTO result.
    ENDCASE.
  ENDMETHOD.


  METHOD technical_name.
    CASE type->kind.
      WHEN cl_abap_typedescr=>kind_elem.
        result = elementary_name( type ).
      WHEN cl_abap_typedescr=>kind_struct.
        result = kind_word( type ).
      WHEN cl_abap_typedescr=>kind_table.
        DATA(line_type) = CAST cl_abap_tabledescr( type )->get_table_line_type( ).
        MESSAGE e231(zatk) WITH describe( line_type ) INTO result.
      WHEN cl_abap_typedescr=>kind_ref.
        result = |REF TO { referenced_name( CAST #( type ) ) }|.
      WHEN OTHERS.
        result = type->get_relative_name( ).
    ENDCASE.
  ENDMETHOD.


  METHOD elementary_name.
    DATA(characters) = type->length / cl_abap_char_utilities=>charsize.
    DATA(packed) = |P LENGTH { type->length } DECIMALS { type->decimals }|.
    result = SWITCH #( type->type_kind
                       WHEN cl_abap_typedescr=>typekind_char   THEN |C LENGTH { characters }|
                       WHEN cl_abap_typedescr=>typekind_num    THEN |N LENGTH { characters }|
                       WHEN cl_abap_typedescr=>typekind_hex    THEN |X LENGTH { type->length }|
                       WHEN cl_abap_typedescr=>typekind_packed THEN packed
                       WHEN cl_abap_typedescr=>typekind_string THEN `STRING`
                       WHEN cl_abap_typedescr=>typekind_xstring THEN `XSTRING`
                       WHEN cl_abap_typedescr=>typekind_int    THEN `I`
                       WHEN cl_abap_typedescr=>typekind_int8   THEN `INT8`
                       WHEN cl_abap_typedescr=>typekind_int1   THEN `INT1`
                       WHEN cl_abap_typedescr=>typekind_int2   THEN `INT2`
                       WHEN cl_abap_typedescr=>typekind_float  THEN `F`
                       WHEN cl_abap_typedescr=>typekind_date   THEN `D`
                       WHEN cl_abap_typedescr=>typekind_time   THEN `T`
                       WHEN cl_abap_typedescr=>typekind_decfloat16 THEN `DECFLOAT16`
                       WHEN cl_abap_typedescr=>typekind_decfloat34 THEN `DECFLOAT34`
                       WHEN cl_abap_typedescr=>typekind_utclong THEN `UTCLONG`
                       ELSE type->get_relative_name( ) ).
  ENDMETHOD.


  METHOD referenced_name.
    DATA(referenced) = type->get_referenced_type( ).
    DATA(is_object) = xsdbool( referenced->kind = cl_abap_typedescr=>kind_class
                            OR referenced->kind = cl_abap_typedescr=>kind_intf ).
    result = COND #( WHEN is_object = abap_true
                     THEN referenced->get_relative_name( )
                     ELSE describe( referenced ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_value_formatter IMPLEMENTATION.

  METHOD format.
    DATA(description) = cl_abap_typedescr=>describe_by_data( value ).
    CASE description->kind.
      WHEN cl_abap_typedescr=>kind_elem.
        result = format_elementary( value     = value
                                    type_kind = description->type_kind ).
      WHEN cl_abap_typedescr=>kind_struct.
        result = format_structure( value       = value
                                   description = CAST #( description ) ).
      WHEN cl_abap_typedescr=>kind_table.
        result = format_table( value ).
      WHEN OTHERS.
        result = format_reference( value ).
    ENDCASE.
    result = shorten( result ).
  ENDMETHOD.


  METHOD format_elementary.
    CASE type_kind.
      WHEN cl_abap_typedescr=>typekind_char OR cl_abap_typedescr=>typekind_string.
        result = |'{ value }'|.
      WHEN cl_abap_typedescr=>typekind_num OR cl_abap_typedescr=>typekind_date OR cl_abap_typedescr=>typekind_time.
        result = |'{ value }'|.
      WHEN OTHERS.
        result = |{ value }|.
    ENDCASE.
  ENDMETHOD.


  METHOD format_structure.
    DATA(parts) = VALUE ty_texts( ).
    LOOP AT description->components INTO DATA(component).
      ASSIGN COMPONENT component-name OF STRUCTURE value TO FIELD-SYMBOL(<component>).
      IF sy-subrc = 0.
        INSERT |{ component-name } = { format( <component> ) }| INTO TABLE parts.
      ENDIF.
    ENDLOOP.
    result = |( { lcl_text=>join( parts ) } )|.
  ENDMETHOD.


  METHOD format_table.
    FIELD-SYMBOLS <table> TYPE ANY TABLE.

    ASSIGN value TO <table>.
    DATA(row_count) = |{ lines( <table> ) }|.
    MESSAGE e209(zatk) WITH row_count INTO result.
  ENDMETHOD.


  METHOD format_reference.
    DATA object_ref TYPE REF TO object.

    IF value IS INITIAL.
      MESSAGE e211(zatk) INTO result.
      RETURN.
    ENDIF.
    DATA(description) = CAST cl_abap_refdescr( cl_abap_typedescr=>describe_by_data( value ) ).
    DATA(referenced_kind) = description->get_referenced_type( )->kind.
    IF referenced_kind <> cl_abap_typedescr=>kind_class AND referenced_kind <> cl_abap_typedescr=>kind_intf.
      MESSAGE e212(zatk) INTO result.
      RETURN.
    ENDIF.
    object_ref = value.
    DATA(class_name) = cl_abap_typedescr=>describe_by_object_ref( object_ref )->get_relative_name( ).
    MESSAGE e210(zatk) WITH class_name INTO result.
  ENDMETHOD.


  METHOD shorten.
    IF strlen( text ) <= max_length.
      result = text.
      RETURN.
    ENDIF.
    DATA(beginning) = substring( val = text
                                 len = max_length ).
    result = |{ beginning }...|.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_name_hint IMPLEMENTATION.

  METHOD closest.
    DATA(fewest_typos) = max_typos + 1.
    LOOP AT candidates INTO DATA(candidate).
      DATA(typos) = distance( val1 = name
                              val2 = candidate ).
      IF typos < fewest_typos.
        fewest_typos = typos.
        result = candidate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD available.
    MESSAGE e208(zatk) INTO DATA(label).
    result = lcl_text=>labeled( label = label
                                text  = lcl_text=>join( candidates ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_call_site IMPLEMENTATION.

  METHOD of_current_call.
    result = origin_in( frames( ) ).
  ENDMETHOD.


  METHOD origin_in.
    LOOP AT frames INTO DATA(line).
      DATA(frame) = parse( line ).
      IF is_machinery( frame ) = abap_false.
        result = describe( frame ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD frames.
    DATA(format) = xco_cp_call_stack=>format->adt( )->with_line_number_flavor(
                       xco_cp_call_stack=>line_number_flavor->include ).
    result = xco_cp=>current->call_stack->full( )->as_text( format )->get_lines( )->value.
  ENDMETHOD.


  METHOD parse.
    SPLIT condense( line ) AT space INTO TABLE DATA(words).
    result-object = to_upper( VALUE string( words[ 1 ] OPTIONAL ) ).
    result-is_system = xsdbool( line CS system_marker ).
    LOOP AT words INTO DATA(word) FROM 2.
      IF word <> system_marker.
        result-event = to_upper( word ).
        EXIT.
      ENDIF.
    ENDLOOP.
    FIND ALL OCCURRENCES OF PCRE standalone_number IN line RESULTS DATA(numbers).
    IF sy-subrc = 0.
      DATA(last) = numbers[ lines( numbers ) ].
      result-line = substring( val = line
                               off = last-offset
                               len = last-length ).
    ENDIF.
  ENDMETHOD.


  METHOD is_machinery.
    IF frame-is_system = abap_true.
      result = abap_true.
    ELSEIF frame-object = own-class_name.
      result = xsdbool( frame-event CP own-stack OR frame-event CP own-origin OR frame-event CP own-answer ).
    ELSE.
      result = xsdbool( frame-object CP framework-classes
                     OR frame-object CP framework-generated
                     OR frame-object CP framework-facade ).
    ENDIF.
  ENDMETHOD.


  METHOD describe.
    result = |{ frame-object }=>{ frame-event }|.
    IF frame-line IS NOT INITIAL.
      MESSAGE e234(zatk) WITH frame-line INTO DATA(line).
      result = |{ result }, { line }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_value_conversion IMPLEMENTATION.

  METHOD copies_losslessly.
    ASSIGN target->* TO FIELD-SYMBOL(<target>).
    DATA(target_type) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data( <target> ) ).
    IF fits_structurally( source      = source
                          target_type = target_type ) = abap_false.
      RETURN.
    ENDIF.
    TRY.
        copy( source = source
              target = target ).
        result = is_same_value( source = source
                                target = <target> ).
      CATCH cx_sy_conversion_error cx_sy_move_cast_error cx_sy_itab_error.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD explain_misfit.
    ASSIGN target->* TO FIELD-SYMBOL(<target>).
    DATA(target_type) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data( <target> ) ).
    IF fits_structurally( source      = source
                          target_type = target_type ) = abap_false.
      result = explain_kind_mismatch( source      = source
                                      target_type = target_type ).
    ELSE.
      result = explain_copy( source = source
                             target = target ).
    ENDIF.
  ENDMETHOD.


  METHOD copy.
    ASSIGN target->* TO FIELD-SYMBOL(<target>).
    DATA(target_type) = cl_abap_typedescr=>describe_by_data( <target> ).
    IF target_type->kind = cl_abap_typedescr=>kind_ref.
      " instance( ) of a double is typed REF TO object; only a down cast gives it the parameter type
      <target> ?= source.
    ELSE.
      <target> = source.
    ENDIF.
  ENDMETHOD.


  METHOD explain_kind_mismatch.
    DATA(source_type) = cl_abap_typedescr=>describe_by_data( source ).
    IF source_type->kind <> target_type->kind.
      MESSAGE e224(zatk) WITH lcl_type_formatter=>kind_word( source_type )
                              lcl_type_formatter=>kind_word( target_type ) INTO result.
    ELSE.
      " same kind, other type: a structure or table of another type, named in full
      MESSAGE e225(zatk) INTO DATA(label).
      result = lcl_text=>labeled( label = label
                                  text  = |{ source_type->absolute_name }| ).
    ENDIF.
  ENDMETHOD.


  METHOD explain_copy.
    ASSIGN target->* TO FIELD-SYMBOL(<target>).
    TRY.
        copy( source = source
              target = target ).
        MESSAGE e226(zatk) INTO DATA(label).
        result = lcl_text=>labeled( label = label
                                    text  = lcl_value_formatter=>format( <target> ) ).
      CATCH cx_sy_conversion_error cx_sy_move_cast_error cx_sy_itab_error INTO DATA(error).
        result = error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD fits_structurally.
    DATA(source_type) = cl_abap_typedescr=>describe_by_data( source ).
    CASE target_type->kind.
      WHEN cl_abap_typedescr=>kind_elem.
        result = xsdbool( source_type->kind = cl_abap_typedescr=>kind_elem ).
      WHEN cl_abap_typedescr=>kind_ref.
        result = xsdbool( source_type->kind = cl_abap_typedescr=>kind_ref ).
      WHEN cl_abap_typedescr=>kind_table.
        result = has_same_line_type( source_type = source_type
                                     target_type = target_type ).
      WHEN OTHERS.
        result = target_type->applies_to_data( source ).
    ENDCASE.
  ENDMETHOD.


  METHOD has_same_line_type.
    IF source_type->kind <> cl_abap_typedescr=>kind_table.
      RETURN.
    ENDIF.
    DATA(source_line) = CAST cl_abap_tabledescr( source_type )->get_table_line_type( ).
    DATA(target_line) = CAST cl_abap_tabledescr( target_type )->get_table_line_type( ).
    result = xsdbool( source_line->absolute_name = target_line->absolute_name ).
  ENDMETHOD.


  METHOD is_same_value.
    DATA exact TYPE decfloat34.

    DATA(target_kind) = cl_abap_typedescr=>describe_by_data( target )->type_kind.
    DATA(source_kind) = cl_abap_typedescr=>describe_by_data( source )->type_kind.
    " a comparison cannot recover from text that is not a number, and rounds text to the
    " decimals of the number; so the text side becomes an exact number by an assignment first
    IF is_numeric( target_kind ) = abap_true AND is_text( source_kind ) = abap_true.
      exact = source.
      result = xsdbool( target = exact ).
    ELSEIF is_text( target_kind ) = abap_true AND is_numeric( source_kind ) = abap_true.
      exact = target.
      result = xsdbool( exact = source ).
    ELSE.
      result = xsdbool( target = source ).
    ENDIF.
  ENDMETHOD.


  METHOD is_numeric.
    result = xsdbool( type_kind = cl_abap_typedescr=>typekind_int
                   OR type_kind = cl_abap_typedescr=>typekind_int1
                   OR type_kind = cl_abap_typedescr=>typekind_int2
                   OR type_kind = cl_abap_typedescr=>typekind_int8
                   OR type_kind = cl_abap_typedescr=>typekind_num
                   OR type_kind = cl_abap_typedescr=>typekind_packed
                   OR type_kind = cl_abap_typedescr=>typekind_float
                   OR type_kind = cl_abap_typedescr=>typekind_decfloat16
                   OR type_kind = cl_abap_typedescr=>typekind_decfloat34 ).
  ENDMETHOD.


  METHOD is_text.
    result = xsdbool( type_kind = cl_abap_typedescr=>typekind_char
                   OR type_kind = cl_abap_typedescr=>typekind_string ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_arguments IMPLEMENTATION.

  METHOD put.
    INSERT VALUE #( name        = name
                    value       = value
                    is_supplied = is_supplied ) INTO TABLE named_values.
  ENDMETHOD.


  METHOD has.
    result = xsdbool( line_exists( named_values[ name = name ] ) ).
  ENDMETHOD.


  METHOD value_of.
    result = VALUE #( named_values[ name = name ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD entries.
    result = named_values.
  ENDMETHOD.


  METHOD size.
    result = lines( named_values ).
  ENDMETHOD.


  METHOD are_met_by.
    result = xsdbool( names_not_met_by( actual ) IS INITIAL ).
  ENDMETHOD.


  METHOD names_not_met_by.
    LOOP AT named_values INTO DATA(expected).
      IF NOT is_met_by( expected = expected
                        actual   = actual ).
        INSERT CONV string( expected-name ) INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_met_by.
    DATA converted TYPE REF TO data.

    DATA(actual_value) = actual->value_of( expected-name ).
    IF actual_value IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN expected-value->* TO FIELD-SYMBOL(<expected>).
    ASSIGN actual_value->* TO FIELD-SYMBOL(<actual>).
    " a generic parameter can get a value of any type; compare only values of the same type
    CREATE DATA converted LIKE <expected>.
    IF lcl_value_conversion=>copies_losslessly( source = <actual>
                                                target = converted ) = abap_false.
      RETURN.
    ENDIF.
    ASSIGN converted->* TO FIELD-SYMBOL(<converted>).
    result = xsdbool( <converted> = <expected> ).
  ENDMETHOD.


  METHOD describe.
    IF named_values IS INITIAL.
      MESSAGE e206(zatk) INTO result.
      RETURN.
    ENDIF.
    DATA(parts) = VALUE ty_texts( FOR argument IN named_values
                                  ( describe_argument( argument ) ) ).
    result = lcl_text=>join( parts ).
  ENDMETHOD.


  METHOD describe_argument.
    ASSIGN argument-value->* TO FIELD-SYMBOL(<value>).
    result = |{ argument-name } = { lcl_value_formatter=>format( <value> ) }|.
    IF argument-is_supplied = abap_false.
      " the caller left the optional parameter out; ATK cannot see its DEFAULT value
      MESSAGE e213(zatk) INTO DATA(label).
      result = |{ result } { label }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_doubled_method IMPLEMENTATION.

  METHOD constructor.
    method_naming = naming.
    declared_exceptions = description-exceptions.
    LOOP AT description-parameters INTO DATA(parameter).
      INSERT VALUE #( name        = parameter-name
                      kind        = parameter-parm_kind
                      is_optional = parameter-is_optional
                      data_type   = parameter_type( owner          = owner
                                                    method_name    = description-name
                                                    parameter_name = parameter-name ) )
             INTO TABLE parameter_list.
    ENDLOOP.
  ENDMETHOD.


  METHOD name.
    result = method_naming-name.
  ENDMETHOD.


  METHOD call_name.
    result = method_naming-call_name.
  ENDMETHOD.


  METHOD add_input.
    DATA(parameter) = find_parameter( parameter_name ).
    IF parameter-kind <> cl_abap_objectdescr=>importing AND parameter-kind <> cl_abap_objectdescr=>changing.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>not_an_input
                                   context = VALUE #( value1 = name( )
                                                      value2 = parameter-name
                                                      value3 = kind_name( parameter-kind ) ) ).
    ENDIF.
    add_argument( arguments = arguments
                  parameter = parameter
                  value     = value ).
  ENDMETHOD.


  METHOD add_output.
    DATA(parameter) = find_parameter( parameter_name ).
    IF parameter-kind <> cl_abap_objectdescr=>exporting AND parameter-kind <> cl_abap_objectdescr=>changing.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>not_an_output
                                   context = VALUE #( value1 = name( )
                                                      value2 = parameter-name
                                                      value3 = kind_name( parameter-kind ) ) ).
    ENDIF.
    add_argument( arguments = arguments
                  parameter = parameter
                  value     = value ).
  ENDMETHOD.


  METHOD returning_value.
    DATA(parameter) = VALUE ty_parameter( parameter_list[ kind = cl_abap_objectdescr=>returning ] OPTIONAL ).
    IF parameter IS INITIAL.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>no_returning_parameter
                                   context = VALUE #( value1  = name( )
                                                      details = describe_outputs( ) ) ).
    ENDIF.
    result = to_value( parameter = parameter
                       value     = value ).
  ENDMETHOD.


  METHOD kind_of.
    result = VALUE #( parameter_list[ name = parameter_name ]-kind OPTIONAL ).
  ENDMETHOD.


  METHOD check_declares.
    IF exception IS NOT BOUND.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>missing_exception
                                   context = VALUE #( value1 = name( ) ) ).
    ENDIF.
    DATA(class_type) = CAST cl_abap_classdescr( cl_abap_typedescr=>describe_by_object_ref( exception ) ).
    DATA(exception_name) = class_type->get_relative_name( ).
    WHILE class_type IS BOUND.
      DATA(class_name) = class_type->get_relative_name( ).
      IF class_name = no_check_root OR line_exists( declared_exceptions[ name = class_name ] ).
        RETURN.
      ENDIF.
      class_type = super_class_of( class_type ).
    ENDWHILE.
    RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>undeclared_exception
                                 context = VALUE #( value1  = name( )
                                                    value2  = exception_name
                                                    details = describe_declared_exceptions( ) ) ).
  ENDMETHOD.


  METHOD recording_arguments.
    LOOP AT parameter_list INTO DATA(parameter) WHERE is_optional = abap_false.
      CASE parameter-kind.
        WHEN cl_abap_objectdescr=>importing.
          INSERT VALUE #( name  = parameter-name
                          kind  = cl_abap_objectdescr=>exporting
                          value = placeholder_for( parameter-data_type ) ) INTO TABLE result.
        WHEN cl_abap_objectdescr=>changing.
          INSERT VALUE #( name  = parameter-name
                          kind  = cl_abap_objectdescr=>changing
                          value = placeholder_for( parameter-data_type ) ) INTO TABLE result.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_arguments.
    result = NEW #( ).
    LOOP AT parameter_list INTO DATA(parameter)
         WHERE kind = cl_abap_objectdescr=>importing OR kind = cl_abap_objectdescr=>changing.
      DATA(argument) = read_argument( atdf_arguments = atdf_arguments
                                      parameter      = parameter ).
      result->put( name        = argument-name
                   value       = argument-value
                   is_supplied = argument-is_supplied ).
    ENDLOOP.
  ENDMETHOD.


  METHOD find_parameter.
    DATA(normalized_name) = to_upper( condense( parameter_name ) ).
    result = VALUE #( parameter_list[ name = normalized_name ] OPTIONAL ).
    IF result IS INITIAL.
      raise_unknown_parameter( normalized_name ).
    ENDIF.
  ENDMETHOD.


  METHOD raise_unknown_parameter.
    DATA(names) = VALUE ty_texts( FOR parameter IN parameter_list
                                  ( CONV string( parameter-name ) ) ).
    DATA(suggestion) = lcl_name_hint=>closest( name       = parameter_name
                                               candidates = names ).
    IF suggestion IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>unknown_param_did_you_mean
                                   context = VALUE #( value1 = name( )
                                                      value2 = parameter_name
                                                      value3 = suggestion ) ).
    ENDIF.
    RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>unknown_parameter
                                 context = VALUE #( value1  = name( )
                                                    value2  = parameter_name
                                                    details = lcl_name_hint=>available( parameter_names( ) ) ) ).
  ENDMETHOD.


  METHOD parameter_names.
    TYPES ty_kinds TYPE STANDARD TABLE OF abap_parmkind WITH EMPTY KEY.

    " inputs first, then outputs, then RETURNING: the order a reader of with( ) and sets( ) expects
    DATA(kinds) = VALUE ty_kinds( ( cl_abap_objectdescr=>importing )
                                  ( cl_abap_objectdescr=>changing )
                                  ( cl_abap_objectdescr=>exporting )
                                  ( cl_abap_objectdescr=>returning ) ).
    LOOP AT kinds INTO DATA(kind).
      LOOP AT parameter_list INTO DATA(parameter) WHERE kind = kind.
        INSERT |{ parameter-name } ({ kind_name( parameter-kind ) })| INTO TABLE result.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD describe_outputs.
    DATA(outputs) = VALUE ty_texts( FOR parameter IN parameter_list
                                    WHERE ( kind = cl_abap_objectdescr=>exporting
                                         OR kind = cl_abap_objectdescr=>changing )
                                    ( |{ parameter-name } ({ kind_name( parameter-kind ) })| ) ).
    IF outputs IS INITIAL.
      MESSAGE e217(zatk) INTO result.
      RETURN.
    ENDIF.
    MESSAGE e216(zatk) INTO DATA(label).
    result = lcl_text=>labeled( label = label
                                text  = lcl_text=>join( outputs ) ).
  ENDMETHOD.


  METHOD describe_declared_exceptions.
    IF declared_exceptions IS INITIAL.
      MESSAGE e219(zatk) INTO result.
      RETURN.
    ENDIF.
    MESSAGE e218(zatk) INTO DATA(label).
    result = lcl_text=>labeled( label = label
                                text  = lcl_text=>join( VALUE #( FOR exception IN declared_exceptions
                                                                 ( CONV string( exception-name ) ) ) ) ).
  ENDMETHOD.


  METHOD add_argument.
    IF arguments->has( parameter-name ).
      MESSAGE e220(zatk) INTO DATA(label).
      DATA(current_value) = arguments->value_of( parameter-name ).
      ASSIGN current_value->* TO FIELD-SYMBOL(<current>).
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>value_given_twice
                                   context = VALUE #( value1  = name( )
                                                      value2  = parameter-name
                                                      details = lcl_text=>labeled(
                                                          label = label
                                                          text  = lcl_value_formatter=>format( <current> ) ) ) ).
    ENDIF.
    arguments->put( name  = parameter-name
                    value = to_value( parameter = parameter
                                      value     = value ) ).
  ENDMETHOD.


  METHOD to_value.
    result = new_value_for( parameter = parameter
                            template  = value ).
    IF NOT lcl_value_conversion=>copies_losslessly( source = value
                                                    target = result ).
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>value_does_not_fit
                                   context = VALUE #( value1  = lcl_value_formatter=>format( value )
                                                      value2  = parameter-name
                                                      value3  = type_name_of( parameter )
                                                      details = lcl_value_conversion=>explain_misfit(
                                                          source = value
                                                          target = result ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD read_argument.
    DATA source TYPE REF TO data.

    result-name = parameter-name.
    TRY.
        " a parameter the caller left out is not read: its value stays initial
        result-is_supplied = is_supplied( atdf_arguments = atdf_arguments
                                          parameter      = parameter ).
        IF result-is_supplied = abap_true AND parameter-kind = cl_abap_objectdescr=>changing.
          source = atdf_arguments->get_param_changing( parameter-name ).
        ELSEIF result-is_supplied = abap_true.
          source = atdf_arguments->get_param_importing( parameter-name ).
        ENDIF.
      CATCH cx_root INTO DATA(error).
        " ATDF exceptions are not released for ABAP Cloud; whatever arrives becomes ZCX_ATK
        RAISE EXCEPTION NEW zcx_atk( problem  = zcx_atk=>internal_error
                                     context  = VALUE #( value1  = name( )
                                                         details = error->get_text( ) )
                                     previous = error ).
    ENDTRY.
    result-value = copy_of( source    = source
                            parameter = parameter ).
  ENDMETHOD.


  METHOD is_supplied.
    IF parameter-is_optional = abap_false.
      result = abap_true.
    ELSEIF parameter-kind = cl_abap_objectdescr=>changing.
      result = atdf_arguments->is_changing_param_supplied( parameter-name ).
    ELSE.
      result = atdf_arguments->is_importing_param_supplied( parameter-name ).
    ENDIF.
  ENDMETHOD.


  METHOD parameter_type.
    owner->get_method_parameter_type(
      EXPORTING
        p_method_name       = method_name
        p_parameter_name    = parameter_name
      RECEIVING
        p_descr_ref         = result
      EXCEPTIONS
        parameter_not_found = 1
        method_not_found    = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.
  ENDMETHOD.


  METHOD new_value_for.
    IF parameter-data_type IS BOUND.
      TRY.
          CREATE DATA result TYPE HANDLE parameter-data_type.
          RETURN.
        CATCH cx_sy_create_data_error.
          " generic parameter type such as ANY: keep the type of the value the test passed
      ENDTRY.
    ENDIF.
    CREATE DATA result LIKE template.
  ENDMETHOD.


  METHOD placeholder_for.
    IF data_type IS BOUND.
      TRY.
          CREATE DATA result TYPE HANDLE data_type.
          RETURN.
        CATCH cx_sy_create_data_error.
          " generic parameter type such as ANY or INDEX TABLE: any fitting value will do
      ENDTRY.
    ENDIF.
    DATA(concrete_type) = concrete_type_for( data_type ).
    CREATE DATA result TYPE HANDLE concrete_type.
  ENDMETHOD.


  METHOD concrete_type_for.
    IF data_type IS NOT BOUND.
      result = cl_abap_elemdescr=>get_string( ).
      RETURN.
    ENDIF.
    IF data_type->kind = cl_abap_typedescr=>kind_table OR data_type->type_kind = cl_abap_typedescr=>typekind_table.
      result = cl_abap_tabledescr=>get( cl_abap_elemdescr=>get_string( ) ).
      RETURN.
    ENDIF.
    result = SWITCH #( data_type->type_kind
                       WHEN cl_abap_typedescr=>typekind_char
                       THEN cl_abap_elemdescr=>get_c( generic_fallback-text_length )
                       WHEN cl_abap_typedescr=>typekind_num
                       THEN cl_abap_elemdescr=>get_n( generic_fallback-text_length )
                       WHEN cl_abap_typedescr=>typekind_hex
                       THEN cl_abap_elemdescr=>get_x( generic_fallback-text_length )
                       WHEN cl_abap_typedescr=>typekind_packed
                       THEN cl_abap_elemdescr=>get_p( p_length   = generic_fallback-packed_length
                                                      p_decimals = generic_fallback-decimals )
                       WHEN cl_abap_typedescr=>typekind_xsequence
                       THEN cl_abap_elemdescr=>get_xstring( )
                       WHEN cl_abap_typedescr=>typekind_numeric OR cl_abap_typedescr=>typekind_decfloat
                       THEN cl_abap_elemdescr=>get_decfloat34( )
                       ELSE cl_abap_elemdescr=>get_string( ) ).
  ENDMETHOD.


  METHOD copy_of.
    IF source IS NOT BOUND.
      result = placeholder_for( parameter-data_type ).
      RETURN.
    ENDIF.
    ASSIGN source->* TO FIELD-SYMBOL(<source>).
    CREATE DATA result LIKE <source>.
    ASSIGN result->* TO FIELD-SYMBOL(<copy>).
    <copy> = <source>.
  ENDMETHOD.


  METHOD type_name_of.
    result = lcl_type_formatter=>describe( parameter-data_type ).
  ENDMETHOD.


  METHOD kind_name.
    result = SWITCH #( kind
                       WHEN cl_abap_objectdescr=>importing THEN keyword-importing
                       WHEN cl_abap_objectdescr=>exporting THEN keyword-exporting
                       WHEN cl_abap_objectdescr=>changing  THEN keyword-changing
                       ELSE keyword-returning ).
  ENDMETHOD.


  METHOD super_class_of.
    class_type->get_super_class_type(
      RECEIVING
        p_descr_ref           = result
      EXCEPTIONS
        super_class_not_found = 1
        OTHERS                = 2 ).
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_doubled_type IMPLEMENTATION.

  METHOD describe.
    DATA description TYPE REF TO cl_abap_typedescr.

    DATA(normalized_name) = to_upper( condense( type_name ) ).
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = normalized_name
      RECEIVING
        p_descr_ref    = description
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>unknown_type
                                   context = VALUE #( value1 = normalized_name ) ).
    ENDIF.
    IF description->kind = cl_abap_typedescr=>kind_class.
      " ABAP Cloud code cannot reach the methods of the class ATDF generates for a class double
      " by name, so the calls could not be routed to ATK
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>not_an_interface
                                   context = VALUE #( value1 = normalized_name ) ).
    ENDIF.
    IF description->kind <> cl_abap_typedescr=>kind_intf.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>not_an_object_type
                                   context = VALUE #( value1 = normalized_name ) ).
    ENDIF.
    result = NEW #( description = CAST #( description )
                    type_name   = normalized_name ).
  ENDMETHOD.


  METHOD constructor.
    doubled_type_name = type_name.
    add_methods_of( owner  = description
                    prefix = `` ).
    add_component_interfaces( description ).
  ENDMETHOD.


  METHOD name.
    result = doubled_type_name.
  ENDMETHOD.


  METHOD doubled_methods.
    result = VALUE #( FOR entry IN catalog
                      ( entry-doubled_method ) ).
  ENDMETHOD.


  METHOD find_method.
    DATA(normalized_name) = to_upper( condense( method_name ) ).
    result = lookup( normalized_name ).
    IF result IS NOT BOUND.
      raise_unknown_method( normalized_name ).
    ENDIF.
  ENDMETHOD.


  METHOD method_called_by_atdf.
    DATA(own_prefix) = |{ doubled_type_name }{ component_separator }|.
    DATA(method_name) = to_upper( atdf_name ).
    IF strlen( method_name ) > strlen( own_prefix ) AND method_name CP |{ own_prefix }*|.
      method_name = substring( val = method_name
                               off = strlen( own_prefix ) ).
    ENDIF.
    result = lookup( method_name ).
    IF result IS NOT BOUND.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>internal_error
                                   context = VALUE #( value1 = method_name ) ).
    ENDIF.
  ENDMETHOD.


  METHOD add_methods_of.
    LOOP AT owner->methods INTO DATA(description).
      " a method of a component interface is listed as ZIF_COMPONENT~METHOD here; it is added
      " from its own interface instead, where RTTI knows its parameter types
      DATA(method_name) = |{ prefix }{ description-name }|.
      IF is_configurable( description ) = abap_false OR description-name CS component_separator
          OR line_exists( catalog[ name = method_name ] ).
        CONTINUE.
      ENDIF.
      DATA(doubled_method) = NEW lcl_doubled_method( owner       = owner
                                                     description = description
                                                     naming      = VALUE #( name      = method_name
                                                                            call_name = call_name_of( method_name ) ) ).
      INSERT VALUE #( name           = method_name
                      doubled_method = doubled_method ) INTO TABLE catalog.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_component_interfaces.
    LOOP AT description->interfaces INTO DATA(component).
      DATA(component_type) = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_name( component-name ) ).
      add_methods_of( owner  = component_type
                      prefix = |{ component-name }{ component_separator }| ).
      " a component interface may include interfaces itself; the catalog skips duplicates
      add_component_interfaces( component_type ).
    ENDLOOP.
  ENDMETHOD.


  METHOD call_name_of.
    result = COND #( WHEN method_name NS component_separator
                     THEN |{ doubled_type_name }{ component_separator }{ method_name }|
                     ELSE method_name ).
  ENDMETHOD.


  METHOD lookup.
    result = VALUE #( catalog[ name = method_name ]-doubled_method OPTIONAL ).
    IF result IS BOUND.
      RETURN.
    ENDIF.
    " a method of a component interface may be named without its interface prefix
    DATA(suffix) = |{ component_separator }{ method_name }|.
    DATA(candidates) = VALUE ty_methods( FOR entry IN catalog WHERE ( name CP |*{ suffix }| )
                                         ( entry-doubled_method ) ).
    IF lines( candidates ) = 1.
      result = candidates[ 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD raise_unknown_method.
    DATA(names) = VALUE ty_texts( FOR entry IN catalog
                                  ( entry-name ) ).
    DATA(suggestion) = lcl_name_hint=>closest( name       = method_name
                                               candidates = names ).
    IF suggestion IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>unknown_method_did_you_mean
                                   context = VALUE #( value1 = doubled_type_name
                                                      value2 = method_name
                                                      value3 = suggestion ) ).
    ENDIF.
    RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>unknown_method
                                 context = VALUE #( value1  = doubled_type_name
                                                    value2  = method_name
                                                    details = lcl_name_hint=>available( names ) ) ).
  ENDMETHOD.


  METHOD is_configurable.
    " static methods cannot be doubled, and an alias is the same method as the one it names
    result = xsdbool( description-is_class = abap_false AND description-alias_for IS INITIAL ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_call_journal IMPLEMENTATION.

  METHOD record.
    INSERT VALUE #( called_method = doubled_method
                    arguments     = arguments
                    origin        = origin ) INTO TABLE calls.
  ENDMETHOD.


  METHOD describe_call.
    result = call-arguments->describe( ).
    IF call-origin IS NOT INITIAL.
      MESSAGE e232(zatk) INTO DATA(from).
      result = |{ result } { from } { call-origin }|.
    ENDIF.
  ENDMETHOD.


  METHOD calls_to.
    result = VALUE #( FOR call IN calls WHERE ( called_method = doubled_method )
                      ( call ) ).
  ENDMETHOD.


  METHOD count_matching.
    LOOP AT calls INTO DATA(call) WHERE called_method = doubled_method.
      IF filter->are_met_by( call-arguments ) = abap_true.
        result += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD explain_count.
    MESSAGE e201(zatk) INTO DATA(label).
    DATA(expected) = lcl_text=>labeled( label = label
                                        text  = filter->describe( ) ).
    IF count_matching( doubled_method = doubled_method
                       filter         = filter ) > 0.
      DATA(facts) = describe_matching_calls( doubled_method = doubled_method
                                             filter         = filter ).
    ELSE.
      facts = describe_closest_call( doubled_method = doubled_method
                                     filter         = filter ).
    ENDIF.
    result = lcl_text=>sentences( VALUE #( ( expected ) ( facts ) ) ).
  ENDMETHOD.


  METHOD describe_matching_calls.
    MESSAGE e221(zatk) INTO DATA(label).
    DATA descriptions TYPE ty_texts.

    LOOP AT calls INTO DATA(call) WHERE called_method = doubled_method.
      IF filter->are_met_by( call-arguments ) = abap_true.
        INSERT |({ describe_call( call ) })| INTO TABLE descriptions.
      ENDIF.
    ENDLOOP.
    result = lcl_text=>labeled( label = label
                                text  = lcl_text=>join( descriptions ) ).
  ENDMETHOD.


  METHOD describe_closest_call.
    DATA(closest) = closest_call( doubled_method = doubled_method
                                  filter         = filter ).
    IF closest-arguments IS NOT BOUND.
      MESSAGE e205(zatk) INTO result.
      RETURN.
    ENDIF.
    MESSAGE e202(zatk) INTO DATA(label).
    result = lcl_text=>labeled( label = label
                                text  = describe_call( closest ) ).
    DATA(differing) = filter->names_not_met_by( closest-arguments ).
    IF differing IS NOT INITIAL.
      MESSAGE e207(zatk) INTO label.
      result = lcl_text=>sentences( VALUE #( ( result )
                                         ( lcl_text=>labeled( label = label
                                                              text  = lcl_text=>join( differing ) ) ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD describe_calls.
    MESSAGE e204(zatk) INTO DATA(label).
    DATA(descriptions) = VALUE ty_texts( FOR call IN calls WHERE ( called_method = doubled_method )
                                         ( |({ describe_call( call ) })| ) ).
    result = lcl_text=>labeled( label = label
                                text  = lcl_text=>join( descriptions ) ).
  ENDMETHOD.


  METHOD closest_call.
    DATA fewest_differences TYPE i.

    LOOP AT calls INTO DATA(call) WHERE called_method = doubled_method.
      DATA(differences) = lines( filter->names_not_met_by( call-arguments ) ).
      IF result-arguments IS NOT BOUND OR differences < fewest_differences.
        result = call.
        fewest_differences = differences.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_call_rule IMPLEMENTATION.

  METHOD constructor.
    me->doubled_method = doubled_method.
    rule_sequence = sequence.
    counts_calls = is_expectation.
    conditions = NEW #( ).
    outputs = NEW #( ).
  ENDMETHOD.


  METHOD zif_atk_call_rule~with.
    add_condition( parameter = parameter
                   value     = value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_rule~returns.
    set_returning( value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_rule~sets.
    add_output( parameter = parameter
                value     = value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_rule~raises.
    set_exception( exception ).
  ENDMETHOD.


  METHOD zif_atk_call_expectation~with.
    add_condition( parameter = parameter
                   value     = value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_expectation~times.
    IF expected_calls < 1.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>invalid_expected_calls
                                   context = VALUE #( value1 = doubled_method->name( )
                                                      value2 = |{ expected_calls }| ) ).
    ENDIF.
    me->expected_calls = expected_calls.
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_expectation~returns.
    set_returning( value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_expectation~sets.
    add_output( parameter = parameter
                value     = value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_expectation~raises.
    set_exception( exception ).
  ENDMETHOD.


  METHOD is_for.
    result = xsdbool( me->doubled_method = doubled_method ).
  ENDMETHOD.


  METHOD applies_to.
    result = conditions->are_met_by( arguments ).
  ENDMETHOD.


  METHOD outranks.
    DATA(own_conditions) = conditions->size( ).
    DATA(other_conditions) = other->conditions->size( ).
    IF own_conditions <> other_conditions.
      result = xsdbool( own_conditions > other_conditions ).
    ELSEIF is_open( ) <> other->is_open( ).
      result = is_open( ).
    ELSE.
      result = xsdbool( rule_sequence > other->rule_sequence ).
    ENDIF.
  ENDMETHOD.


  METHOD is_open.
    result = xsdbool( counts_calls = abap_false OR call_count < expected_calls ).
  ENDMETHOD.


  METHOD describe_conditions.
    result = |({ conditions->describe( ) })|.
  ENDMETHOD.


  METHOD unmet_conditions.
    result = conditions->names_not_met_by( arguments ).
  ENDMETHOD.


  METHOD answer.
    call_count += 1.
    TRY.
        IF exception_to_raise IS BOUND.
          atdf_result->raise_exception( exception_to_raise ).
          RETURN.
        ENDIF.
        write_outputs( atdf_result ).
      CATCH cx_root INTO DATA(error).
        " ATDF exceptions are not released for ABAP Cloud; whatever arrives becomes ZCX_ATK
        RAISE EXCEPTION NEW zcx_atk( problem  = zcx_atk=>internal_error
                                     context  = VALUE #( value1  = doubled_method->name( )
                                                         details = error->get_text( ) )
                                     previous = error ).
    ENDTRY.
  ENDMETHOD.


  METHOD is_satisfied.
    result = xsdbool( call_count = expected_calls ).
  ENDMETHOD.


  METHOD unmet_expectation.
    result = NEW #( problem = zcx_atk=>wrong_call_count
                    context = VALUE #( value1  = doubled_method->name( )
                                       value2  = |{ expected_calls }|
                                       value3  = |{ call_count }|
                                       details = journal->explain_count( doubled_method = doubled_method
                                                                         filter         = conditions ) ) ).
  ENDMETHOD.


  METHOD add_condition.
    doubled_method->add_input( arguments      = conditions
                               parameter_name = parameter
                               value          = value ).
  ENDMETHOD.


  METHOD add_output.
    ensure_no_exception( ).
    doubled_method->add_output( arguments      = outputs
                                parameter_name = parameter
                                value          = value ).
  ENDMETHOD.


  METHOD set_returning.
    ensure_no_exception( ).
    IF returning_value IS BOUND.
      raise_answer_already_set( `returns( )` ).
    ENDIF.
    returning_value = doubled_method->returning_value( value ).
  ENDMETHOD.


  METHOD set_exception.
    ensure_no_exception( ).
    IF returning_value IS BOUND.
      raise_answer_already_set( `returns( )` ).
    ELSEIF outputs->size( ) > 0.
      raise_answer_already_set( `sets( )` ).
    ENDIF.
    doubled_method->check_declares( exception ).
    exception_to_raise = exception.
  ENDMETHOD.


  METHOD ensure_no_exception.
    IF exception_to_raise IS BOUND.
      raise_answer_already_set( `raises( )` ).
    ENDIF.
  ENDMETHOD.


  METHOD raise_answer_already_set.
    RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>answer_already_set
                                 context = VALUE #( value1 = doubled_method->name( )
                                                    value2 = answer ) ).
  ENDMETHOD.


  METHOD write_outputs.
    IF returning_value IS BOUND.
      ASSIGN returning_value->* TO FIELD-SYMBOL(<returning>).
      atdf_result->set_param_returning( <returning> ).
    ENDIF.
    LOOP AT outputs->entries( ) INTO DATA(output).
      ASSIGN output-value->* TO FIELD-SYMBOL(<output>).
      IF doubled_method->kind_of( output-name ) = cl_abap_objectdescr=>changing.
        atdf_result->set_param_changing( name  = output-name
                                         value = <output> ).
      ELSE.
        atdf_result->set_param_exporting( name  = output-name
                                          value = <output> ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_rulebook IMPLEMENTATION.

  METHOD new_rule.
    result = NEW #( doubled_method = doubled_method
                    sequence       = lines( all_rules ) + 1
                    is_expectation = is_expectation ).
    INSERT result INTO TABLE all_rules.
  ENDMETHOD.


  METHOD best_rule.
    LOOP AT all_rules INTO DATA(rule).
      IF rule->is_for( doubled_method ) = abap_false OR rule->applies_to( arguments ) = abap_false.
        CONTINUE.
      ENDIF.
      IF result IS NOT BOUND OR rule->outranks( result ) = abap_true.
        result = rule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_rules_for.
    LOOP AT all_rules INTO DATA(rule).
      IF rule->is_for( doubled_method ) = abap_true.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD rules.
    result = all_rules.
  ENDMETHOD.


  METHOD explain_no_match.
    DATA closest TYPE REF TO lcl_call_rule.
    DATA fewest_unmet TYPE i.

    DATA(candidates) = rules_for( doubled_method ).
    LOOP AT candidates INTO DATA(rule).
      DATA(unmet) = lines( rule->unmet_conditions( arguments ) ).
      IF closest IS NOT BOUND OR unmet < fewest_unmet.
        closest = rule.
        fewest_unmet = unmet.
      ENDIF.
    ENDLOOP.
    DATA(conditions) = VALUE ty_texts( FOR candidate IN candidates
                                       ( candidate->describe_conditions( ) ) ).
    DATA(facts) = VALUE ty_texts( ( lcl_text=>labeled( label = list_label
                                                       text  = lcl_text=>join( conditions ) ) ) ).
    IF closest IS BOUND AND fewest_unmet > 0.
      INSERT lcl_text=>labeled( label = closest_label
                                text  = lcl_text=>join( closest->unmet_conditions( arguments ) ) ) INTO TABLE facts.
    ENDIF.
    result = lcl_text=>sentences( facts ).
  ENDMETHOD.


  METHOD rules_for.
    LOOP AT all_rules INTO DATA(rule).
      IF rule->is_for( doubled_method ) = abap_true.
        INSERT rule INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_call_verification IMPLEMENTATION.

  METHOD constructor.
    me->doubled_method = doubled_method.
    recorded_calls = journal.
    failure_reporter = reporter.
    conditions = NEW #( ).
  ENDMETHOD.


  METHOD zif_atk_call_verification~with.
    doubled_method->add_input( arguments      = conditions
                               parameter_name = parameter
                               value          = value ).
    self = me.
  ENDMETHOD.


  METHOD zif_atk_call_verification~times.
    IF expected_calls < 0.
      RAISE EXCEPTION NEW zcx_atk( problem = zcx_atk=>negative_expected_calls
                                   context = VALUE #( value1 = doubled_method->name( )
                                                      value2 = |{ expected_calls }| ) ).
    ENDIF.
    DATA(actual_calls) = recorded_calls->count_matching( doubled_method = doubled_method
                                                         filter         = conditions ).
    IF actual_calls <> expected_calls.
      failure_reporter->report_verification( NEW #(
          problem = zcx_atk=>wrong_call_count
          context = VALUE #( value1  = doubled_method->name( )
                             value2  = |{ expected_calls }|
                             value3  = |{ actual_calls }|
                             details = recorded_calls->explain_count( doubled_method = doubled_method
                                                                      filter         = conditions ) ) ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_call_router IMPLEMENTATION.

  METHOD constructor.
    described_type = doubled_type.
    double_role = role.
    failure_reporter = reporter.
    call_rules = NEW #( ).
    recorded_calls = NEW #( ).
  ENDMETHOD.


  METHOD doubled_type.
    result = described_type.
  ENDMETHOD.


  METHOD rulebook.
    result = call_rules.
  ENDMETHOD.


  METHOD journal.
    result = recorded_calls.
  ENDMETHOD.


  METHOD reporter.
    result = failure_reporter.
  ENDMETHOD.


  METHOD if_abap_testdouble_answer~answer.
    TRY.
        DATA(doubled_method) = described_type->method_called_by_atdf( method_name ).
        DATA(call) = VALUE lcl_call_journal=>ty_call(
            called_method = doubled_method
            arguments     = doubled_method->read_arguments( arguments )
            origin        = lcl_call_site=>of_current_call( ) ).
        recorded_calls->record( doubled_method = call-called_method
                                arguments      = call-arguments
                                origin         = call-origin ).
        respond( call        = call
                 atdf_result = result ).
      CATCH zcx_atk INTO DATA(failure).
        failure_reporter->report_during_act( failure ).
      CATCH cx_root INTO DATA(error).
        " nothing may escape into the code under test, where a CATCH could hide it
        failure_reporter->report_during_act( NEW #( problem  = zcx_atk=>internal_error
                                                    context  = VALUE #( value1  = method_name
                                                                        details = error->get_text( ) )
                                                    previous = error ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD respond.
    IF double_role = lif_role=>dummy.
      failure_reporter->report_during_act( failure_for( problem = zcx_atk=>dummy_called
                                                        call    = call ) ).
      RETURN.
    ENDIF.
    DATA(rule) = call_rules->best_rule( doubled_method = call-called_method
                                        arguments      = call-arguments ).
    IF rule IS BOUND.
      rule->answer( atdf_result ).
      RETURN.
    ENDIF.
    DATA(has_rules) = call_rules->has_rules_for( call-called_method ).
    IF double_role = lif_role=>mock AND has_rules = abap_false.
      failure_reporter->report_during_act( failure_for( problem = zcx_atk=>unexpected_call
                                                        call    = call ) ).
    ELSEIF has_rules = abap_true.
      DATA(problem) = COND zcx_atk=>ty_problem( WHEN double_role = lif_role=>mock
                                                THEN zcx_atk=>no_matching_expectation
                                                ELSE zcx_atk=>no_matching_rule ).
      DATA(explanation) = explain_no_match( doubled_method = call-called_method
                                            arguments      = call-arguments ).
      failure_reporter->report_during_act( failure_for( problem     = problem
                                                        call        = call
                                                        explanation = explanation ) ).
    ENDIF.
  ENDMETHOD.


  METHOD failure_for.
    MESSAGE e203(zatk) INTO DATA(label).
    DATA(first_value) = COND string( WHEN problem = zcx_atk=>dummy_called
                                     THEN described_type->name( )
                                     ELSE call-called_method->name( ) ).
    DATA(facts) = VALUE ty_texts( ( lcl_text=>labeled( label = label
                                                       text  = call-arguments->describe( ) ) ) ).
    IF call-origin IS NOT INITIAL.
      MESSAGE e233(zatk) INTO label.
      INSERT lcl_text=>labeled( label = label
                                text  = call-origin ) INTO TABLE facts.
    ENDIF.
    IF explanation IS NOT INITIAL.
      INSERT explanation INTO TABLE facts.
    ENDIF.
    result = NEW #( problem = problem
                    context = VALUE #( value1  = first_value
                                       value2  = call-called_method->name( )
                                       details = lcl_text=>sentences( facts ) ) ).
  ENDMETHOD.


  METHOD explain_no_match.
    DATA list_label TYPE string.
    DATA closest_label TYPE string.

    IF double_role = lif_role=>mock.
      MESSAGE e222(zatk) INTO list_label.
      MESSAGE e223(zatk) INTO closest_label.
    ELSE.
      MESSAGE e214(zatk) INTO list_label.
      MESSAGE e215(zatk) INTO closest_label.
    ENDIF.
    result = call_rules->explain_no_match( doubled_method = doubled_method
                                           arguments      = arguments
                                           list_label     = list_label
                                           closest_label  = closest_label ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_double IMPLEMENTATION.

  METHOD constructor.
    call_router = router.
    fake = instance.
  ENDMETHOD.


  METHOD zif_atk_double~instance.
    result = fake.
  ENDMETHOD.


  METHOD zif_atk_stub~when.
    result = call_router->rulebook( )->new_rule( find_method( method_name ) ).
  ENDMETHOD.


  METHOD zif_atk_spy~was_called.
    result = NEW lcl_call_verification( doubled_method = find_method( method_name )
                                        journal        = call_router->journal( )
                                        reporter       = call_router->reporter( ) ).
  ENDMETHOD.


  METHOD zif_atk_spy~was_not_called.
    DATA(doubled_method) = find_method( method_name ).
    DATA(calls) = call_router->journal( )->calls_to( doubled_method ).
    IF calls IS INITIAL.
      RETURN.
    ENDIF.
    call_router->reporter( )->report_verification( NEW #(
        problem = zcx_atk=>unwanted_call
        context = VALUE #( value1  = doubled_method->name( )
                           value2  = |{ lines( calls ) }|
                           details = call_router->journal( )->describe_calls( doubled_method ) ) ) ).
  ENDMETHOD.


  METHOD zif_atk_mock~expect_call.
    result = call_router->rulebook( )->new_rule( doubled_method = find_method( method_name )
                                                 is_expectation = abap_true ).
  ENDMETHOD.


  METHOD zif_atk_mock~verify.
    LOOP AT call_router->rulebook( )->rules( ) INTO DATA(rule).
      IF rule->is_satisfied( ) = abap_false.
        call_router->reporter( )->report_verification( rule->unmet_expectation( call_router->journal( ) ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_method.
    result = call_router->doubled_type( )->find_method( method_name ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_unit_failure_reporter IMPLEMENTATION.

  METHOD lif_failure_reporter~report_during_act.
    " msg is the line of the failure list; detail shows under it, in the Analysis of the
    " SAP GUI result and in the Details node of the ADT view
    cl_abap_unit_assert=>fail( msg    = failure->headline( )
                               detail = failure->explanation( )
                               quit   = if_abap_unit_constant=>quit-no ).
  ENDMETHOD.


  METHOD lif_failure_reporter~report_verification.
    cl_abap_unit_assert=>fail( msg    = failure->headline( )
                               detail = failure->explanation( ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lth_atdf_gateway IMPLEMENTATION.

  METHOD lif_atdf_gateway~create_double.
    TRY.
        result = cl_abap_testdouble=>create( CONV #( doubled_type->name( ) ) ).
      CATCH cx_root INTO DATA(error).
        " ATDF exceptions are not released for ABAP Cloud; whatever arrives becomes ZCX_ATK
        RAISE EXCEPTION NEW zcx_atk( problem  = zcx_atk=>atdf_create_failed
                                     context  = VALUE #( value1  = doubled_type->name( )
                                                         details = error->get_text( ) )
                                     previous = error ).
    ENDTRY.
  ENDMETHOD.


  METHOD lif_atdf_gateway~route_calls.
    LOOP AT doubled_type->doubled_methods( ) INTO DATA(doubled_method).
      route_method( atdf_double    = double
                    doubled_method = doubled_method
                    answer         = answer ).
    ENDLOOP.
  ENDMETHOD.


  METHOD route_method.
    DATA(call_name) = doubled_method->call_name( ).
    DATA(recording_arguments) = doubled_method->recording_arguments( ).
    TRY.
        cl_abap_testdouble=>configure_call( atdf_double
          )->ignore_all_parameters(
          )->times( unlimited_calls
          )->set_answer( answer ).
        " the method is known only at runtime, so the dynamic form is the only way to call it
        CALL METHOD atdf_double->(call_name) PARAMETER-TABLE recording_arguments.
      CATCH cx_root INTO DATA(error).
        " ATDF exceptions are not released for ABAP Cloud; whatever arrives becomes ZCX_ATK
        RAISE EXCEPTION NEW zcx_atk( problem  = zcx_atk=>atdf_route_failed
                                     context  = VALUE #( value1  = call_name
                                                         details = error->get_text( ) )
                                     previous = error ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS lth_double_factory IMPLEMENTATION.

  METHOD standard.
    result = NEW #( reporter = NEW lcl_unit_failure_reporter( )
                    gateway  = NEW lth_atdf_gateway( ) ).
  ENDMETHOD.


  METHOD constructor.
    failure_reporter = reporter.
    atdf_gateway = gateway.
  ENDMETHOD.


  METHOD create.
    DATA(doubled_type) = lcl_doubled_type=>describe( type_name ).
    DATA(router) = NEW lcl_call_router( doubled_type = doubled_type
                                        role         = role
                                        reporter     = failure_reporter ).
    DATA(fake) = atdf_gateway->create_double( doubled_type ).
    atdf_gateway->route_calls( double       = fake
                               doubled_type = doubled_type
                               answer       = router ).
    result = NEW #( router   = router
                    instance = fake ).
  ENDMETHOD.

ENDCLASS.
