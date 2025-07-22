#include "../sam-pch.h"
#include "scene-environment.h"
#include "scene.h"

#include "Utility/script-component.h"
#include "../Scripts/door-script.h"
#include "Components/game-scene-component.h"
#include "../Gameplay/Components/environmental-component.h"
#include "Rendering/lightComponent.hpp"
#include "Rendering/cameraComponent.hpp"


void spawnDoor(glm::vec3 pos, artemis::Entity* button, bool* globalOpen)
{
	//auto* door = SCENE.LoadPrefab(active_directory + "Prefabs/ActualDoor.prefab");
	//auto* tc = (TransformComponent*)door->getComponent<TransformComponent>();

	//tc->local.position = glm::vec4(pos, 1.f);
	//tc->world[3] = tc->local.position;

	//std::unique_ptr<Script> ds = std::make_unique<DoorScript>(door, button, &inventory, 0, false, globalOpen);
	//door->addComponent(new ScriptComponent(std::move(ds)));
	//door->addComponent(new HeadNodeComponent());
	//door->refresh();
}



artemis::Entity* spawnHole(glm::vec3 pos, glm::vec3 extents)
{
	auto* hole = SCENE.LoadPrefab(active_directory + "Prefabs/Hole.prefab");
	auto* holeTrans = (TransformComponent*)hole->getComponent<TransformComponent>();

	holeTrans->local.position = glm::vec4(pos, 1.f);
	holeTrans->world[3] = holeTrans->local.position;
	//rockCol->body->setMassProps(0.1f, btVector3(0, 0 , 0));

	hole->addComponent(new Cmp_Environmental(Environmental::Hole));
	//hole->addComponent(new Cmp_Damage(1, spawnPoint));
	hole->addComponent(new HeadNodeComponent());
	hole->refresh();

	return hole;
}

std::pair<artemis::Entity*, artemis::Entity*> findLightCam()
{
	bool lightFound = false, camFound = false;
	artemis::Entity* light = nullptr;
	artemis::Entity* cam = nullptr;

	for (auto* p : SCENE.parents) {
		if (!lightFound) {
			const auto* lc = (LightComponent*)p->data->getComponent<LightComponent>();
			if (lc != nullptr) {
				light = p->data;
				lightFound = true;
			}
		}
		if (!camFound) {
			const auto* cc = (CameraComponent*)p->data->getComponent<CameraComponent>();
			if (cc != nullptr) {
				cam = p->data;
				camFound = true;
				auto* audio = (AudioComponent*)p->data->getComponent<AudioComponent>();
				if (audio == nullptr) {
					p->data->addComponent(new AudioComponent(active_directory + "Audio/pickupCoin.wav"));
					p->data->refresh();
				}
			}
		}
		if (lightFound && camFound) {
			return std::pair<artemis::Entity*, artemis::Entity*>(light, cam);
		}

	}
	return std::pair<artemis::Entity*, artemis::Entity*>();
}

artemis::Entity* findFloor()
{
	for (auto* p : SCENE.parents) {
		if (p->name == "Floor")
			return p->data;
	}
	return nullptr;
}

void LightControl()
{	
	//find light;
	for (auto* p : SCENE.parents) {
		const auto* lc = (LightComponent*)p->data->getComponent<LightComponent>();
		if (lc != nullptr) {
			std::unique_ptr<Script> ls = std::make_unique<LightScript>(p->data);
			p->data->addComponent(new ScriptComponent(std::move(ls)));
		}
	}
}
