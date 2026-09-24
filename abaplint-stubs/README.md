# abaplint stubs

Minimal definitions of SAP objects that abaplint cannot know offline (ABAP Test Double
Framework, ABAP Unit). They exist only so that abaplint can type-check ATK in CI; abapGit
never imports them (its starting folder is `/src/`). Signatures follow SAP's released
objects; if SAP changes one, update the stub.
