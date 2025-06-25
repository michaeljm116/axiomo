#include "../sam-pch.h"
#include "spawn-system.h"
#include "scene-characters.h"

Sys_Spawn::Sys_Spawn()
{
	addComponentType<Cmp_Spawn>();
}

Sys_Spawn::~Sys_Spawn()
{
}

void Sys_Spawn::initialize()
{
	spawn_mapper.init(*world);

	//load_spawner(active_directory + "Config/Enemy_Spawners.xml");
}

void Sys_Spawn::added(artemis::Entity& e)
{
	// Add initial group of enemies
	auto* spawn = spawn_mapper.get(e);
	for (int i = 0; i < spawn->curr_enemies; ++i) {
		auto its = std::to_string(i);
		spawnEnemy(set_rand_position(*spawn), glm::vec3(0), spawn->name + "(" + its + ")", spawn->prefab);
	}

}

void Sys_Spawn::processEntity(artemis::Entity& e)
{
	// Given the spawner time has been reached
	auto* spawn = spawn_mapper.get(e);
	if (curr_time < spawn->start_time_in_seconds) return;

	// And the spawner is not in cooldown
	spawn->curr_cooldown -= world->getGameTick();
	if (spawn->curr_cooldown > 0) return;

	// And It has not gone above max enemies (delete if it has)
	if (spawn->curr_enemies >= spawn->max_enemies) {
		world->deleteEntity(e);
		return;
	}

	// Then Spawn The enemies
	auto num_enemies = std::to_string(++spawn->curr_enemies);
	spawnEnemy(set_rand_position(*spawn), glm::vec3(0), spawn->name + "(" + num_enemies + ")", spawn->prefab);
	spawn->curr_cooldown = spawn->cooldown;
}

void Sys_Spawn::removed(artemis::Entity& e)
{
}

void Sys_Spawn::begin()
{
	curr_time += world->getGameTick();
}

void Sys_Spawn::load_spawner(std::string file)
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
		glm::vec2 extents;
		auto* area = p_curr->FirstChildElement("Area");
		auto* area_position = area->FirstChildElement("Position");
		auto* area_extents = area->FirstChildElement("Extents");
		area_position->QueryFloatAttribute("x", &pos.x);
		area_position->QueryFloatAttribute("y", &pos.y);
		area_position->QueryFloatAttribute("z", &pos.z);
		area_extents->QueryFloatAttribute("x", &extents.x);
		area_extents->QueryFloatAttribute("z", &extents.y);


		int start_time;
		int max_enemies;
		int curr_enemies;
		float cooldown;
		auto* spawner_properties = p_curr->FirstChildElement("Properties");
		spawner_properties->QueryIntAttribute("StartTime", &start_time);
		spawner_properties->QueryIntAttribute("InitialEnemies", &curr_enemies);
		spawner_properties->QueryIntAttribute("MaxEnemies", &max_enemies);
		spawner_properties->QueryFloatAttribute("Cooldown", &cooldown);



		auto* e = &world->getEntityManager()->create();
		e->addComponent(new Cmp_Spawn(start_time, static_cast<float>(cooldown), static_cast<float>(curr_enemies), static_cast<float>(max_enemies), pos, extents, prefab, name));
		e->refresh();

		p_curr = p_curr->NextSiblingElement();
	}
}

glm::vec3 Sys_Spawn::set_rand_position(const Cmp_Spawn& spawn)
{
	std::default_random_engine generator;
	std::uniform_real_distribution<float> dx(spawn.area.x, spawn.area.z);
	std::uniform_real_distribution<float> dz(spawn.area.y, spawn.area.w);

	unsigned seed = static_cast<unsigned>(std::chrono::system_clock::now().time_since_epoch().count());

	generator.seed(seed);
	return glm::vec3(dx(generator), spawn.height, dz(generator));
}
