# Axiomo Game Engine - Agent Guidelines

This file contains guidelines for AI agents working on the Axiomo 3D game engine project built in Odin.

## Build Commands

### Primary Build Commands
```bash
# Debug build (most common during development)
./build_debug.bat

# Debug build with auto-run
./build_debug.bat run

# Debug build with RAD debugger
./build_debug.bat rad

# Hot reload build (for rapid iteration)
./build_hot_reload.bat

# Hot reload with auto-run
./build_hot_reload.bat run

# Release build (optimized)
./build_release.bat
```

### Testing
```bash
# Run tests (currently commented out in main, but available)
odin test src/test -debug -define:ODIN_TEST_THREADS=1

# Single test file (when test framework is enabled)
odin test src/test/specific_test.odin -debug
```

### Code Quality (planned)
Future builds will include `-strict-style -vet` flags for code quality enforcement.

## Code Style Guidelines

### Naming Conventions
- **Packages**: `lowercase` (e.g., `game`, `axiom`)
- **Procedures**: `snake_case` (e.g., `game_init`, `app_update`)
- **Types**: `PascalCase` (e.g., `Game_Memory`, `BattleState`)
- **Variables**: `snake_case` for locals, `PascalCase` for globals
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `USE_TRACKING_ALLOCATOR`)
- **Components**: `Cmp_*` prefix (e.g., `Cmp_Transform`, `Cmp_Mesh`)
- **Systems**: `sys_*` prefix (e.g., `sys_render`, `sys_physics`)

### Import Organization
```odin
package main

import (
    "core:fmt"
    "core:log"
    "axiom:ecs"
    "axiom:gpu"
    "game:components"
    "game:systems"
)
```

### File Organization
- Keep related functionality in the same package
- Use clear, descriptive file names
- Separate engine code (`axiom/`) from game logic (`game/`)
- External dependencies go in `axiom/external/`

### Code Structure Patterns
- Use procedure-based programming over OOP
- Leverage Odin's struct methods where appropriate
- Follow ECS patterns: components for data, systems for logic
- Use arena allocators for memory management

### Error Handling
- Use `or_else` operator for error propagation
- Log errors with context information
- Return error codes from procedures that can fail
- Use `defer` for cleanup operations

### Documentation Style
- Use section dividers: `//------------\\`
- Add TODO comments with context: `// TODO: Implement feature X`
- Document complex algorithms with inline comments
- Use meaningful variable and procedure names

## Architecture Guidelines

### Entity-Component-System (ECS)
- Components should contain only data, no logic
- Systems operate on entity queries using views
- Use tag tables for entity categorization
- Keep components small and focused

### Memory Management
- Use arena allocators for different lifetimes:
  - `core_allocator`: permanent engine memory
  - `game_allocator`: game session memory
  - `frame_allocator`: temporary per-frame memory
- Enable tracking allocator in debug builds for leak detection
- Clean up resources explicitly

### Rendering Pipeline
- Vulkan-based with custom shader management
- Use BVH for collision detection and ray tracing
- Materials defined in XML configuration files
- Shaders compiled separately and loaded at runtime

### Asset Management
- Textures: `assets/textures/`
- Models: `assets/models/` (`.pm` format)
- Audio: `assets/audio/`
- Prefabs: `assets/prefabs/` (`.json`)
- Scenes: `assets/scenes/` (`.json`)
- Config: `assets/config/` (`.xml`)

## Development Workflow

### Hot Reload Development
- Use `./build_hot_reload.bat run` for rapid iteration
- Game logic reloads automatically when rebuilt
- Debug with logging to file system
- Test changes immediately without restart

### Debugging
- Use RAD Debugger integration: `./build_debug.bat rad`
- Enable logging for troubleshooting
- Use memory tracking in debug builds
- Test with different build configurations

### Testing Strategy
- Unit tests in `src/test/` package
- Integration tests for major systems
- Performance testing for rendering pipeline
- Regression tests for critical game mechanics

## Project-Specific Patterns

### Game State Management
- Use enum-based state system (TitleScreen, MainMenu, Game, etc.)
- Implement state transition procedures
- Keep state data separate from state logic

### Battle System
- Queue-based turn management
- Component-based character stats
- Event-driven action resolution

### UI System
- Component-based interface elements
- Layout management with containers
- Input handling through event system

## Tool Integration

### Editor Configuration
- VS Code: Use provided `tasks.json` and `launch.json`
- Zed Editor: Configuration available in `.zed/`
- Odin Language Server: Configure with `ols.json`

### Build System
- Batch scripts for different build modes
- No Makefile or CMake - use provided scripts
- Icon editing with `rcedit-x64.exe`

## Important Notes

- This is a Vulkan-based game engine - graphics code is complex
- ECS architecture requires understanding of ODE_ECS library
- Memory management is critical - always use appropriate allocators
- Hot reload system enables rapid development iteration
- Asset pipeline uses custom formats and loading systems

## Common Pitfalls to Avoid

- Don't mix memory allocators - use the right one for the lifetime
- Don't add logic to components - keep them data-only
- Don't ignore error handling - Vulkan operations can fail
- Don't modify external dependencies - use wrapper extensions instead
- Don't commit build artifacts - only source code and assets