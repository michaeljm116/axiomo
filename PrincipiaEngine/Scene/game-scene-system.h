#pragma once
#include "Components/game-scene-component.h"
#include "../Gameplay/Components/gameObjectTypeComponent.h"

#include <Artemis/Artemis.h>

#include <glm/glm.hpp>
#include "../Scene/scene.h"

#include "../Gameplay/interactable-system.h"

/*
Eventually: it will allow you to load and save your own game scenes
Now: it will just pop things up for a test run so its a scene start spawning system
When you add a game scene component it will start and then pop that component out
- so that its not constantly processing

It creates entities of:
 - Player
 - Enemies

*/
using namespace Principia;

class GameSceneSystem : public artemis::EntityProcessingSystem {

public:
	GameSceneSystem();
	~GameSceneSystem();

	void initialize() override;
	void begin() override;
	void end() override;
	void added(artemis::Entity &e) override;
	void removed(artemis::Entity& e) override {};
	void processEntity(artemis::Entity& e) override {};

	void start_up();
	void UpdateGameSettings(artemis::Entity& e);
	void import_scene_script(std::string file);
	void change_scene();

private:
	artemis::ComponentMapper<GameSceneComponent> gscMapper;
	artemis::ComponentMapper<GameSettingsComponent> settings_mapper;
	
	artemis::Entity* GetPacman();
	void ColorTheCandy(NodeComponent* nc);
	artemis::Entity* spawnGUI(std::string name, GUIComponent* gui);

	//PACMANY STUFF
	void LoadGraph(const std::string& file);

	//GameSystem* sys_Game;
	Sys_Interactable* sys_Interactable;

	Inventory inventory;

	bool started_up = false;
};
