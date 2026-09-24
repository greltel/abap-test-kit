"! <p class="shorttext synchronized" lang="EN">ABAP Test Kit: what every test double offers</p>
"! What every test double of the ABAP Test Kit offers: the fake object you hand to the code under test.
INTERFACE zif_atk_double PUBLIC.

  "! Returns the fake object. CAST it to the doubled type where you inject it, for example
  "! <em>NEW zcl_order_service( CAST #( repository->instance( ) ) )</em>.
  "! @parameter result | Object implementing the doubled interface or extending the doubled class
  METHODS instance
    RETURNING VALUE(result) TYPE REF TO object.

ENDINTERFACE.
