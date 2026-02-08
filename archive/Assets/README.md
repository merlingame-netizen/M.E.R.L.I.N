# Archive (Project Cleanup)

Purpose
- Store deprecated or superseded project files (non-docs).
- Reduce clutter while keeping recovery possible.

Structure
- scenes: legacy or duplicate scenes
- scripts: legacy or duplicate scripts
- colab: older notebook versions
- artifacts: large build exports or temporary packages
- temp: staging or scratch data

Rules
- Do not move active production assets here.
- If a file is still referenced by scenes or scripts, keep it in place.

Moved in this cleanup
- scenes: MenuPrincipal.tscn, TestMerlinGBA.tscn, TestMerlin_GBA.tscn (legacy/duplicate)
- scenes: TestTaniere.tscn (removed from menu, replaced by Collection)
- scripts: MenuPrincipal.gd, MenuPrincipalStyled.gd, menu_principal_animated.gd, MainMenu.gd, main_menu.gd, main_menu_ui.gd, menu_3d_controller.gd, menu_camera.gd, test_merlin_gba.gd (+ .uid)
- scripts: TestTaniere.gd (+ .uid) (removed with scene)
- colab: older Compile_* notebooks (kept latest in root)
- artifacts: merlin_llm_sources.zip, merlin_llm_sources.tar.gz, DRU_colab_src.tgz
- temp: __colab_stage staging folder
