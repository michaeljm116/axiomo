#pragma once
#include <Artemis/EntityProcessingSystem.h>
#include <Artemis/ComponentMapper.h>
#include "Components/spawn-component.h"
#include <chrono>

class Sys_Spawn : public artemis::EntityProcessingSystem {
public:
	Sys_Spawn();
	~Sys_Spawn();

	void initialize() override;
	void added(artemis::Entity& e) override;
	void processEntity(artemis::Entity& e) override;
	void removed(artemis::Entity& e) override;
	void begin() override;

	void load_spawner(std::string file);
	glm::vec3 set_rand_position(const Cmp_Spawn& spawn);
private:
	artemis::ComponentMapper<Cmp_Spawn> spawn_mapper = artemis::ComponentMapper<Cmp_Spawn>();
	float curr_time = 0.f;
};