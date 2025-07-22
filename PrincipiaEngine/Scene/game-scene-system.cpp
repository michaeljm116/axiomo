
//#include "../pch.h"
#include "../sam-pch.h"
#include "game-scene-system.h"
#include "../Application/Components/controllerComponent.hpp"
#include "../Physics/Components/collisionComponent.h"
#include "../Gameplay/Components/gameObjectTypeComponent.h"
#include "../Utility/game-component-flags.h"
#include "../Utility/prefabComponent.h"
#include "Utility/xxhash.hpp"
#include "Utility/script-component.h"
#include <unordered_set>
#include "../Gameplay/Components/movement-component.h"
#include "../Gameplay/Components/attack-component.h"
#include "../Gameplay/Components/interactable-component.h"
//#include "../Scripts/battery-door-script.h"
#include "../Scene/scene.h"
#include "../Scripts/follow-froku-script.h"
#include "../Scripts/bird-script.h"
#include "../Scripts/candy-script.h"


//#include "../Utility/LevelGenerator/pacman_lvl_detector.h"
#include "../Utility/LevelGenerator/image_convert.h"
#include "../Utility/LevelGenerator/graph.h"

#include "scene-characters.h"
#include "scene-items.h"
#include "scene-environment.h"
#include "../Scripts/rooms-script.h"
#include "cast.h"

GameSceneSystem::GameSceneSystem()
{
	addComponentType<GameSceneComponent>();
	addComponentType<GameSettingsComponent>();
}

GameSceneSystem::~GameSceneSystem()
{
}

void GameSceneSystem::initialize()
{
	gscMapper.init(*world);
	settings_mapper.init(*world);

	//sys_Game = (GameSystem*)world->getSystemManager()->getSystem<GameSystem>();
	sys_Interactable = (Sys_Interactable*)world->getSystemManager()->getSystem<Sys_Interactable>();

}

void GameSceneSystem::begin()
{
}

void GameSceneSystem::end()
{
}

void GameSceneSystem::added(artemis::Entity& e)
{
	auto* gsc = gscMapper.get(e);
	if (gsc->sceneChanged) {
		change_scene();
	}
	else {

		int lvl = gscMapper.get(e)->levelIndex;
		e.removeComponent<GameSceneComponent>();

		auto* gdc = (GlobalDataComponent*)world->getSingleton()->getComponent<GlobalDataComponent>();
		if (started_up) {
			auto* froku = gdc->main_character_data.entity;
			auto light_cam = findLightCam();
			UpdateGameSettings(e);

			/*std::unique_ptr<Script> ffs = std::make_unique<FollowFrokuScript>(froku, light_cam);
			froku->addComponent(new ScriptComponent(std::move(ffs)));*/

			//import_scene_script("../Assets/Levels/1_Jungle/Config/Arena_Game.xml");

			//spawnSnake();
		}
	}
	
}

void GameSceneSystem::start_up()
{	
	started_up = true;
	artemis::Entity* froku = nullptr;
	auto* gdc = (GlobalDataComponent*)world->getSingleton()->getComponent<GlobalDataComponent>();

	froku = spawnFroku(&gdc->main_character_data);
	gdc->main_character_data.entity = froku;
	
	std::unique_ptr<Script> room_script = std::make_unique<Scr_Rooms>(froku, gdc->level_directory, "/Config/RoomData.xml");
	auto* scene = world->getScene();
	world->getSingleton()->addComponent(new ScriptComponent(std::move(room_script)));

}

void GameSceneSystem::UpdateGameSettings(artemis::Entity& e)
{
	auto* settings = settings_mapper.get(e);
	auto* gdc = (GlobalDataComponent*)e.getComponent<GlobalDataComponent>();
	//auto* physics = (Cmp_Physics*)world->getSingleton()->getComponent<Cmp_Physics>();

	//physics->dynamicsWorld->setGravity(btVector3(0, settings->settings.find("Gravity")->second[0].value, 0));
	//gdc->main_character_data.moveRef->jumpSpeed = settings->settings.find("Speed")->second[1].value;
	//gdc->main_character_data.moveRef->walkSpeed = settings->settings.find("Speed")->second[0].value;

	gdc->speed.player = settings->settings.find("Speed")->second[0].value;
	gdc->speed.enemy = settings->settings.find("Speed")->second[1].value;
	gdc->light.intensity = settings->settings.find("Light")->second[0].value;
	gdc->light.light_y = settings->settings.find("Light")->second[1].value;
	gdc->light.light_z = settings->settings.find("Light")->second[2].value;
	gdc->distance.camera_y = settings->settings.find("Distance")->second[0].value;
	gdc->distance.camera_z = settings->settings.find("Distance")->second[1].value;
	gdc->times.pill = settings->settings.find("Timer")->second[0].value;
	gdc->times.fruit = settings->settings.find("Timer")->second[1].value;
	gdc->times.respawn = settings->settings.find("Timer")->second[2].value;
}

void GameSceneSystem::import_scene_script(std::string file)
{
	//Load file
	tinyxml2::XMLDocument doc;
	auto e_result = doc.LoadFile(file.c_str());
	assert(e_result == tinyxml2::XMLError::XML_SUCCESS);

	//Get to first Node
	auto* p_node = doc.FirstChild();
	auto* p_root = doc.FirstChildElement("Root");
	auto* p_curr = p_root->FirstChildElement("Node");

	//Pasre File
	while (p_curr != nullptr) {
		const char* name;
		const char* prefab;
		const char* type;

		p_curr->QueryStringAttribute("Name", &name);
		p_curr->QueryStringAttribute("Prefab", &prefab);
		p_curr->QueryStringAttribute("Type", &type);

		glm::vec3 pos;
		glm::vec3 rot;
		glm::vec3 sca;
		auto* transform = p_curr->FirstChildElement("Transform");
		auto* position = transform->FirstChildElement("Position");
		auto* rotation = transform->FirstChildElement("Rotation");
		auto* scale = transform->FirstChildElement("Scale");
		position->QueryFloatAttribute("x", &pos.x);
		position->QueryFloatAttribute("y", &pos.y);
		position->QueryFloatAttribute("z", &pos.z);
		
		rotation->QueryFloatAttribute("x", &rot.x);
		rotation->QueryFloatAttribute("y", &rot.y);
		rotation->QueryFloatAttribute("z", &rot.z);
		
		scale->QueryFloatAttribute("x", &sca.x);
		scale->QueryFloatAttribute("y", &sca.y);
		scale->QueryFloatAttribute("z", &sca.z);
		
		//if(strcmp(name,"Bear"))
			spawnEnemyAnim(pos, rot, name, prefab);
		//else
		//	spawnEnemy(pos, rot, name, prefab);



		p_curr = p_curr->NextSiblingElement();
	}
}

void GameSceneSystem::change_scene()
{
	//auto* gdc = (GlobalDataComponent*)world->getSingleton()->getComponent<GlobalDataComponent>();
	////artemis::Entity& froku = *spawnFroku(&gdc->main_character_data);
	////UpdateGameSettings(e);
	////sys_Interactable->sceneChanged(froku);
	////spawnPoint = gdc->main_character_data.pos;
	////handleSpawns(gsc->levelIndex, &froku);
	////e.removeComponent<GameSceneComponent>();

	//artemis::Entity& jabby = *spawnJabbyBird(&gdc->main_character_data);
	//UpdateGameSettings(e);
	//e.removeComponent<GameSceneComponent>();

	//auto light_cam = findLightCam();
	////auto* light = light_cam.first;
	////std::unique_ptr<Script> ls = std::make_unique<LightScript>(light);
	////light->addComponent(new ScriptComponent(std::move(ls)));
	////light->refresh();
	//std::unique_ptr<Script> ffs = std::make_unique<FollowFrokuScript>(&jabby, light_cam);
	//jabby.addComponent(new ScriptComponent(std::move(ffs)));
	//sys_Interactable->sceneChanged(jabby);
}

artemis::Entity* GameSceneSystem::GetPacman()
{
	for (auto* p : SCENE.parents) {
		if (p->name == "BlacMan")
			return p->data;
	}
	return nullptr;
}

void GameSceneSystem::ColorTheCandy(NodeComponent* nc)
{

}

artemis::Entity* GameSceneSystem::spawnGUI(std::string name, GUIComponent* gui)
{
	artemis::Entity* gui_ent = &world->getEntityManager()->create();
	gui_ent->addComponent(gui); 
	gui_ent->addComponent(new RenderComponent(RenderType::RENDER_GUI));
	gui_ent->addComponent(new NodeComponent(gui_ent, name, COMPONENT_GUI));
	SCENE.AddEntityToScene(gui_ent);
	gui_ent->refresh();

	return gui_ent;
}

void GameSceneSystem::LoadGraph(const std::string& file)
{
	auto img = lvlgen::Image(file);
	auto converter = lvlgen::ImageConverter(img);
	std::vector<std::vector<bool>> grid = std::vector<std::vector<bool>>(converter.ColorMatrix().size(), std::vector<bool>(converter.ColorMatrix()[0].size()));
	for (int r = 0; r < static_cast<int>(converter.ColorMatrix().size()); ++r) {
		for (int c = 0; c < static_cast<int>(converter.ColorMatrix()[0].size()); ++c) {
			if (converter.ColorMatrix()[r][c] == lvlgen::kColorBlue) grid[r][c] = false;
			else grid[r][c] = true;
		}
	}
	lvlgen::Graph graf = lvlgen::Graph(to_int(grid.size()), to_int(grid[0].size()));
	graf.build(grid);
}

