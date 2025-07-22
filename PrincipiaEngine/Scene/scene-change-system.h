#pragma once
/*
Scene Change System Copyright (C) 2020 by Mike Murrell
An Entity Processing System that:
	- Stores a Hash map of every Scene.xml file
	- Changes level whenever the world's singleton get's triggered
OnAdd: It destroys teh current scene
	   Pauses the GameLoop
	   Loads new Scene
OnProcess: It optionally animates a transition
OnRemove: Unpauses the Game Loop
*/


#include <Artemis/EntityProcessingSystem.h>
#include <Artemis/ComponentMapper.h>
#include "Components/scene-trigger-component.h"
#include "Physics/Components/collisionComponent.h"
#include "../Application/Components/applicationComponents.h"
#include "../Gameplay/Components/character-component.hpp"

#include <unordered_map>



using namespace Principia;
class SceneChangeSystem : public artemis::EntityProcessingSystem {
public:
	SceneChangeSystem();
	~SceneChangeSystem();

	void initialize() override;
	void added(artemis::Entity &e) override;
	void processEntity(artemis::Entity &e) override;
	void removed(artemis::Entity &e) override;

private:
	artemis::ComponentMapper<SceneTriggerComponent> triggerMapper = {};
	artemis::ComponentMapper<CollidedComponent> coldMapper = {};


	std::unordered_map<int, std::string> sceneMap = {};
	std::unordered_map<int, std::string> dirMap = {};

	int currentDir = 0;
	float timer = 0;
	bool playerHit = false;

	void handlePlayerHit(artemis::Entity& e, artemis::Entity* player);
	void CreateDataBase();
	//Quick function to make a key/val pair of a level
	inline std::pair<int, std::string> makeItem(std::string name)
	{
		return std::pair((int)xxh::xxhash<32, char>(name.c_str(), 0), name);
	}



	
};