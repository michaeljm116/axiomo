#include "../pch.h"
#include "Utility/debug-component.hpp"
#include "Components/grid-component.h"
#include "gridSystem.h"

GridSystem::GridSystem()
{
	addComponentType<Cmp_Grid>();
	addComponentType<Cmp_Debug>();
	//addComponentType<Principia::TransformComponent>();
}

GridSystem::~GridSystem()
{
}

void GridSystem::initialize()
{
	gridMapper.init(*world);
	debugMapper.init(*world);
	//transMapper.init(*world);
}

void GridSystem::processEntity(artemis::Entity & e)
{

}

void GridSystem::added(artemis::Entity & e)
{

}

void GridSystem::removed(artemis::Entity & e)
{

}
void GridSystem::setGridSize(uint8_t x, uint8_t y)
{

}

void GridSystem::displayGrid()
{

}
