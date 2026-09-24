"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: create test doubles</p>
"! Entry point of the ABAP Test Kit. Creates the four kinds of test doubles from the name of a
"! global interface or a non-final global class. Pick the kind by what your test needs:
"! <ul>
"! <li>{@link .METH:dummy} - the collaborator must be passed in, but is never used</li>
"! <li>{@link .METH:stub} - the code under test asks the collaborator for data</li>
"! <li>{@link .METH:spy} - the code under test tells the collaborator to do something</li>
"! <li>{@link .METH:mock} - every call must be declared up front, any other call fails</li>
"! </ul>
CLASS zcl_atk DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  FOR TESTING.

  PUBLIC SECTION.
    "! Use me when the code under test needs this collaborator to be passed in, but your
    "! test never uses it. If the code calls me anyway, the test fails and names the call.
    "! Raises ZCX_ATK if the type cannot be doubled, and says why.
    "! @parameter type_name | Global interface or non-final global class, for example 'ZIF_LOGGER'
    "! @parameter result    | The dummy; inject the object returned by its instance( )
    CLASS-METHODS dummy
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zif_atk_dummy.

    "! Use me when the code under test asks this collaborator for data and your test
    "! decides the answer. Check the result of the code under test, not the stub.
    "! Raises ZCX_ATK if the type cannot be doubled, and says why.
    "! @parameter type_name | Global interface or non-final global class
    "! @parameter result    | The stub; configure it with when( )
    CLASS-METHODS stub
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zif_atk_stub.

    "! Use me when the code under test tells this collaborator to do something and your
    "! test checks after the act step that it was told correctly. I can answer like a stub.
    "! Raises ZCX_ATK if the type cannot be doubled, and says why.
    "! @parameter type_name | Global interface or non-final global class
    "! @parameter result    | The spy; check it with was_called( ) after the act step
    CLASS-METHODS spy
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zif_atk_spy.

    "! Use me when every call must be declared before the act step and any other call
    "! must fail the test at once. End the test with verify( ). If unsure, use a spy.
    "! Raises ZCX_ATK if the type cannot be doubled, and says why.
    "! @parameter type_name | Global interface or non-final global class
    "! @parameter result    | The mock; declare its calls with expect_call( )
    CLASS-METHODS mock
      IMPORTING type_name     TYPE csequence
      RETURNING VALUE(result) TYPE REF TO zif_atk_mock.

ENDCLASS.


CLASS zcl_atk IMPLEMENTATION.

  METHOD dummy.
    result = lth_double_factory=>standard( )->create( type_name = type_name
                                                      role      = lif_role=>dummy ).
  ENDMETHOD.


  METHOD stub.
    result = lth_double_factory=>standard( )->create( type_name = type_name
                                                      role      = lif_role=>stub ).
  ENDMETHOD.


  METHOD spy.
    result = lth_double_factory=>standard( )->create( type_name = type_name
                                                      role      = lif_role=>spy ).
  ENDMETHOD.


  METHOD mock.
    result = lth_double_factory=>standard( )->create( type_name = type_name
                                                      role      = lif_role=>mock ).
  ENDMETHOD.

ENDCLASS.
