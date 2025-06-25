#include "rooms-script.h"
#include "../Vendor/tinyxml2/tinyxml2.h"
#include "../Scene/scene-characters.h"
#include "../Scene/scene.h"
#include "camera-script.h"
#include <filesystem>
#pragma once

#pragma region Helper Lambdas

auto check_boundary = [](glm::vec4 player_pos, Scr_Rooms::Room room) {
	if (player_pos.x > room.boundary.right) return 'r';
	if (player_pos.x < room.boundary.left) return 'l';
	if (player_pos.z > room.boundary.up) return 't';
	if (player_pos.z < room.boundary.down) return 'b';
	return 'y';
};

const float dist_from_boundary = 1.5f;
auto set_player_start = [](char door_exit, Scr_Rooms::Room next_room, glm::vec4 player_pos) {
	glm::vec4 new_pos = player_pos;
	switch (door_exit) {
		case 'r': return glm::vec4(next_room.boundary.left + dist_from_boundary, player_pos.y, player_pos.z, player_pos.w);
		case 'l': return glm::vec4(next_room.boundary.right - dist_from_boundary, player_pos.y, player_pos.z, player_pos.w);
		case 't': return glm::vec4(player_pos.x, player_pos.y, next_room.boundary.down + dist_from_boundary, player_pos.w);
		case 'b': return glm::vec4(player_pos.x, player_pos.y, next_room.boundary.up - dist_from_boundary, player_pos.w);
	}
	return new_pos;
};

#pragma endregion


Scr_Rooms::Scr_Rooms()
{
}

Scr_Rooms::Scr_Rooms(artemis::Entity* e, std::string directory, std::string file)
	: MainPlayer(e), level_directory(directory), file(file)
{
	load_rooms(directory + file);	
	curr_room = &rooms[first_room];
	player_transform = (TransformComponent*)MainPlayer->getComponent<TransformComponent>();
}

auto find_cam = [](NodeComponent* n) { return n->name == "Camera"; };
auto get_scene_camera = []() {
	//return std::find(SCENE.parents.begin(), SCENE.parents.end(), find_cam)[0]->data;
	//assert(n_camera != SCENE.parents.end());
	for (auto* nc : SCENE.parents) {
		if(nc->name == "Camera")
			return nc->data;
	}

	artemis::Entity* nullentity = nullptr;
	return nullentity;
};


void Scr_Rooms::added()
{
	//SCENE.deleteSceneExceptPlayer();
	if(SCENE.parents.size() > 1)
		SCENE.deleteSceneExceptPlayer();
	SCENE.LoadNewScene(first_room); 
	spawn_enemies();

	auto* camera = get_scene_camera();
	std::unique_ptr<Script> camera_script = std::make_unique<Scr_Camera>(camera, MainPlayer);
	Scr_Camera* scr_camera = static_cast<Scr_Camera*>(camera_script.get());
	scr_camera->set_camera_type(curr_room->camera_type);
	camera->addComponent(new ScriptComponent(std::move(camera_script)));
}

void Scr_Rooms::process(float dt)
{
	// Detect when player enters, leaves room
	glm::vec4 player_pos = player_transform->local.position;
	char in_room = check_boundary(player_pos, *curr_room);
	if (in_room != 'y') {
		std::string next_room = curr_room->doors[in_room];
		player_transform->local.position = set_player_start(in_room, next_room, player_pos);
		CollisionComponent* col = (CollisionComponent*)MainPlayer->getComponent<CollisionComponent>();
		player_transform->world[3] = player_transform->local.position;
		col->body->setWorldTransform(g2bt(player_transform->world));
		auto p = SCENE.parents;
		//Change to the new room
		SCENE.deleteSceneExceptPlayer();
		SCENE.LoadNewScene(next_room);
		curr_room = &rooms[next_room];
		spawn_enemies();
		//Spawn player
		//spawnFroku()
			// Spawn Enemies
		// TODO Save State of Current Room using tinyxml2 
		// so that if an enemy dies it keeps track of it
		// or if an item is taken etc...

		auto* camera = get_scene_camera();
		std::unique_ptr<Script> camera_script = std::make_unique<Scr_Camera>(camera, MainPlayer);
		Scr_Camera* scr_camera = static_cast<Scr_Camera*>(camera_script.get());
		scr_camera->set_camera_type(curr_room->camera_type);
		camera->addComponent(new ScriptComponent(std::move(camera_script)));
	}
}

void Scr_Rooms::removed()
{
	std::cout << "ROOMS SCRIPT REMOVED";
}

void Scr_Rooms::load_rooms(std::string file)
{	//Load file
	tinyxml2::XMLDocument doc;
	auto e_result = doc.LoadFile(file.c_str());
	assert(e_result == tinyxml2::XMLError::XML_SUCCESS);

	//Get to first Node
	auto* p_node = doc.FirstChild();
	auto* p_root = doc.FirstChildElement("Root");
	auto* p_room = p_root->FirstChildElement("Room");
	
	//Parse File
	assert(p_root != nullptr);
	const char* first_room_name;
	p_root->QueryStringAttribute("first_room", &first_room_name);
	assert(first_room_name != nullptr);
	first_room = first_room_name;

	while (p_room != nullptr) {
		const char* room_name;
		const char* camera_type;
		int num_doors;
		int num_enemies;
		int num_items;

		p_room->QueryStringAttribute("name", &room_name);
		p_room->QueryIntAttribute("num_doors", &num_doors);
		p_room->QueryIntAttribute("num_enemies", &num_enemies);
		p_room->QueryIntAttribute("num_items", &num_items);
		p_room->QueryStringAttribute("camera_type", &camera_type);

		Room room(room_name);
		room.camera_type = camera_type;
		if (num_doors > 0) {
			auto* p_exit = p_room->FirstChildElement("Exit");
			while (p_exit != nullptr) {
				const char* exit_name;
				const char* door;
				p_exit->QueryStringAttribute("name", &exit_name);
				p_exit->QueryStringAttribute("door", &door);
				p_exit = p_exit->NextSiblingElement("Exit");

				assert(door[0] == 'r' || door[0] == 'l' || door[0] == 't' || door[0] == 'b');
				room.doors.insert({door[0], exit_name});
			}
		}
		if (num_enemies > 0) 
		{
			auto* p_enemy = p_room->FirstChildElement("Enemy");
			int i = 0;
			while (p_enemy != nullptr) 
			{
				i++;
				const char* enemy_name = "";
				const char* enemy_prefab = "";
				const char* item = "";
				bool alive = true;
				float x = 0; 
				float y = 0;

				p_enemy->QueryStringAttribute("name", &enemy_name);
				p_enemy->QueryStringAttribute("prefab", &enemy_prefab);
				p_enemy->QueryStringAttribute("item", &item);
				p_enemy->QueryBoolAttribute("alive", &alive);
				assert(!(enemy_prefab == ""));

				auto* p_position = p_enemy->FirstChildElement("Position");
				p_position->QueryFloatAttribute("x", &x);
				p_position->QueryFloatAttribute("y", &y);
				auto s_enemy_name = std::string(enemy_name) + std::to_string(i);
				Cmp_Enemy enemy_component = {s_enemy_name.c_str(), enemy_prefab, item, alive, glm::vec2(x, y)};
				room.enemies.insert({ s_enemy_name, enemy_component});
				p_enemy = p_enemy->NextSiblingElement("Enemy");
			}
		}
		rooms.insert({ room_name, room });
		p_room = p_room->NextSiblingElement("Room");
	}
}

void Scr_Rooms::spawn_player(glm::vec4 pos, glm::quat rot)
{
	//possibly not needed
}

void Scr_Rooms::spawn_enemies()
{
	for (auto e : curr_room->enemies) {
		auto c_enemy = e.second;
		if (c_enemy.alive)
		spawnEnemyAnim(glm::vec3(c_enemy.spawn_point.x, player_transform->local.position.y, c_enemy.spawn_point.y), glm::vec3(0), c_enemy.name, c_enemy.prefab);
		//enemy->addComponent(new Cmp_Enemy(c_enemy));
	}
}

void Scr_Rooms::set_enemy_death(std::string en, glm::vec3 pos)
{
	Cmp_Enemy* enemy = &curr_room->enemies[en];
	assert(enemy != nullptr);
	enemy->alive = false;
 	enemy->spawn_point = glm::vec2(pos.x, pos.z);

	//if (enemy->item != "")
	//{
	//	Cmp_Item* item = &curr_room->items[enemy->item];
	//	assert(item != nullptr);
	//	item->visible = true;
	//	item->spawn_point = enemy->spawn_point;
	//	//spawnItem()
	//}
	

}
