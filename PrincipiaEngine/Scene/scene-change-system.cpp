#include "scene-change-system.h"
#include <filesystem>
#include "LevelDB.h"
#include "scene.h"

#include "../Scene/Components/game-scene-component.h"
#pragma once

//todo THIS ENTIRE THING IS RLY BAD CODE CHANGE LATER
SceneChangeSystem::SceneChangeSystem()
{
	addComponentType<SceneTriggerComponent>();
	addComponentType<CollidedComponent>();
	//addComponentType<ApplicationComponent>();
}

SceneChangeSystem::~SceneChangeSystem()
{
}

void SceneChangeSystem::initialize()
{
	//Initialize the mappers
	triggerMapper.init(*world);
	//appMapper.init(*world);
	coldMapper.init(*world);

	//Set up the directories
	CreateDataBase();
	currentDir = dirMap.begin()->first;

	//Create a hash map of every scene
	size_t i = 0, size = dirMap.size();
	for (const auto & n : dirMap) {
		for (const auto & p : std::filesystem::directory_iterator("../Assets/Levels/" + n.second + "/Scenes/")) {
			const std::string& path = p.path().stem().string();
			const int key = xxh::xxhash<32, char>(path.c_str(), 0);
			sceneMap.insert(std::pair<int, std::string>(key, path));
		}
	}
}

void SceneChangeSystem::added(artemis::Entity & e)
{
	CollidedComponent* cc = coldMapper.get(e);
	Cmp_Character* ccomp = nullptr;
	int id = 0;
	for (auto ent : cc->collidedWith) {
		auto* player = &world->getEntity(ent.id);
		ccomp = (Cmp_Character*)player->getComponent<Cmp_Character>();		
		if (ccomp != nullptr) {
			playerHit = true;
			handlePlayerHit(e, player);
			return;
		}
	}
	return;
}

void SceneChangeSystem::processEntity(artemis::Entity & e)
{
	//check for player if not player found yet;
	if (!playerHit) {
		CollidedComponent* cc = coldMapper.get(e);
		for (auto ent : cc->collidedWith) {
			auto* player = &world->getEntity(ent.id);
			auto* ccomp = (Cmp_Character*)player->getComponent<Cmp_Character>();
			if (ccomp != nullptr) {
				playerHit = true;
				handlePlayerHit(e, player);
				return;
			}
		}
	}
	else {
		//Iterate the timer, if it hits its max then end it
		timer += world->getDelta();
		if (timer > 1.f) {
			world->getSingleton()->removeComponent<SceneTriggerComponent>();
		}
	}
}

void SceneChangeSystem::removed(artemis::Entity & e)
{
	//Unpause the Game Loop
	if (playerHit) {
		ApplicationComponent* ac = (ApplicationComponent*)world->getSingleton()->getComponent<ApplicationComponent>();
		ac->state = AppState::Play;
		playerHit = false;
		//world->getSingleton()->addComponent(new GameSceneComponent(0));
		world->getSingleton()->refresh();
	}
}

void SceneChangeSystem::handlePlayerHit(artemis::Entity& e, artemis::Entity* player)
{
	//Get data for the transfer
	SceneTriggerComponent stc = *triggerMapper.get(e);
	glm::vec3 playerPos = ((TransformComponent*)player->getComponent<TransformComponent>())->local.position;
	playerPos[stc.axis] = stc.newPosition[stc.axis];
	playerPos = stc.newPosition;
	auto* gdc = (GlobalDataComponent*)world->getSingleton()->getComponent<GlobalDataComponent>();
	gdc->main_character_data.pos = playerPos;
	gdc->main_character_data.destroyed();

	//Delete and load scene
	SCENE.deleteScene();					//if (stc.dir != currentDir) {} //TODO: have a way to load a new directory
	SCENE.LoadScene(sceneMap[stc.scene]);


	//create a new froku
	int a = SCENE.sceneNumber;
	world->getSingleton()->addComponent(new GameSceneComponent(a,true));

	////////////////////////////DONT LET ME GET AWAY WITH THIS!!!!!!!!!!////////////////////
	timer = 0;
}

void SceneChangeSystem::CreateDataBase()
{
	dirMap.insert(std::pair((int)xxh::xxhash<32, char>("Test", 0), "Test"));
	//dirMap.insert(std::pair((int)xxh::xxhash<32, char>("Level1", 0), "Level1"));

	//dirMap.insert(makeItem("Level1"));
}



