#pragma once
/*
Mike Murrell 2025 Grid System
Keeps track of all objects on a grid
compares their position with stuff
if on a grid it lets ya know

Notes:
So for a grid you want "ultimately a 3d grid but lets stay 2d for now with 2/3 states for the bee"
So ultimately, a grid wants to know what the level size is and what the grid number is
Then as you move it keeps track of that ratio
question is... do you want a 2d array of ... or is it just...
each component is calculated aka will it be a theoretical grid or an actual grid
everything depends on... what your plans are with the grid
grid purposes:
    to place objects on to
    for ai
    for timing calculations like the movement speed of player/bee
IF
    you need it for object blocking paths
    consistent sizing of things
    pathfinding with blocked objects
THEN
    its necessary to have an array
    MAYBE
*/

#include <Artemis/EntityProcessingSystem.h>
#include <Artemis/ComponentMapper.h>

struct Cmp_Grid;
using Principia::Cmp_Debug;
//class Principia::TransformComponent;

class GridSystem : public artemis::EntityProcessingSystem {
public:
	GridSystem();
	~GridSystem();

	void initialize() override;
	void processEntity(artemis::Entity &e) override;
	void added(artemis::Entity &e) override;
	void removed(artemis::Entity &e) override;
	void setGridSize(uint8_t x, uint8_t y);
	void displayGrid();

private:
	artemis::ComponentMapper<Cmp_Grid> gridMapper;
	artemis::ComponentMapper<Cmp_Debug> debugMapper;
	//artemis::ComponentMapper<Principia::TransformComponent> transMapper;


};