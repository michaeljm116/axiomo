# BeeKillinsInn
* This is a Top-Down 3D turn based grid based strategy rpg
* Odin Programming Language
* Custom Game Engine "Axiomo"
# Axiomo
* Compute Shader Raytraced Vulkan Rendering
* Found in src/axiom/render.odin, also uses src/axiom/gpu/gpu.odin for its gpu interface
* ECS based Engine separated into 2 files, src/axiom/components.odin and src/axiom/systems.odin
* Arena Based memory allocation found in src/axiom/memory.odin, lifecycles are important
* * Memory life cycles have comments on them in src/game.odin that describe their life
* Windows/Input found in src/axiom/window.odin, glfw window system, input abstracts to a custom controller
* api.odin defines certain globals and sets up ecs and helper functions
# Game
* Interface.odin interfaces with axiom engine with helper functions
* game.odin is the main entry point, then goes and calls app.odin as the next layer of interface
* most of the game code is in battle.odin, and next important will be grid.odin
* overworld is still underdeveloped as well as levels.odin and may go through many changes. battle and grid are mature
* there's other helpers in idk and edit.odin which will probably be removed upon game release
# Battle
* Uses a queued turn based system
* Visual Event System is a system for processing events and performing animations in between player/game decisions
* * Notice it has 2 main functions 1. Visual 2. Event 
# Build
* build_debug.bat is the main building function,
* build_hot_reload.bat and the main_hot_reload folder are currently not working so ignore for now
# Test
* odin test src/test -debug -define:ODIN_TEST_THREADS=1
* odin test src/axiomo/test -debug -define:ODIN_TEST_THREADS=1
* odin test src/axiomo/extentions/tests -debug -define:ODIN_TEST_THREADS=1