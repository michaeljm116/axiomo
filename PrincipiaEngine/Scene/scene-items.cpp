#include "../sam-pch.h"
#include "scene-items.h"


#include "../Gameplay/Components/collectible-component.h"


#include "../Scripts/spring-script.h"
#include "../Scripts/drop-chest-script.h"
#include "../Scripts/rock-fall-script.h"
#include "scene.h"

void spawnHeart(glm::vec3 pos)
{
	auto* heart = SCENE.LoadPrefab(active_directory + "Prefabs/Heart.prefab");
	auto* tc = (TransformComponent*)heart->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;

	std::unique_ptr<Script> ts = std::make_unique<HeartScript>(heart);
	heart->addComponent(new ScriptComponent(std::move(ts)));

	heart->addComponent(new Cmp_Collectible(Collectible::Heart));
	heart->addComponent(new HeadNodeComponent());
	heart->refresh();
}

void spawnSpring(glm::vec3 pos, artemis::Entity* f)
{
	auto* spring = SCENE.LoadPrefab(active_directory + "Prefabs/Spring.prefab");
	auto* tc = (TransformComponent*)spring->getComponent<TransformComponent>();
	auto* cc = (CollisionComponent*)spring->getComponent<CollisionComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;
	cc->mass = 0.3f;

	int32_t inna = Interactable::StepOn | Interactable::Push;
	//auto* cmpinna = new Cmp_Interactable(inna);
	auto* cmpinna = new Cmp_Interactable(Interactable::StepOn);
	cmpinna->distance = 2.f;

	spring->addComponent(cmpinna);
	std::unique_ptr<Script> ss = std::make_unique<SpringScript>(spring, f);
	spring->addComponent(new ScriptComponent(std::move(ss)));
	spring->addComponent(new HeadNodeComponent());
	spring->refresh();
}

artemis::Entity* spawnChest(glm::vec3 pos, bool* global)
{
	auto* chest = SCENE.LoadPrefab(active_directory + "Prefabs/Chest.prefab");
	auto* tc = (TransformComponent*)chest->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;


	NodeComponent* nc = (NodeComponent*)chest->getComponent<NodeComponent>();
	nc->isParent = true;
	BFGraphComponent* bfg = new BFGraphComponent();
	flatten(bfg->nodes, nc);
	chest->addComponent(bfg);

	chest->addComponent(new Cmp_Interactable(Interactable::Chest));
	//chest->addComponent(new Cmp_Interactable(Interactable::PushBlock));
	chest->addComponent(new HeadNodeComponent());
	chest->refresh();

	return chest;
}

artemis::Entity* spawnDropChest(glm::vec3 pos, Cmp_Interactable* button, bool* global, bool* global2)
{
	auto* chest = SCENE.LoadPrefab(active_directory + "Prefabs/Chest.prefab");
	auto* tc = (TransformComponent*)chest->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;


	NodeComponent* nc = (NodeComponent*)chest->getComponent<NodeComponent>();
	nc->isParent = true;
	BFGraphComponent* bfg = new BFGraphComponent();
	flatten(bfg->nodes, nc);
	chest->addComponent(bfg);

	chest->addComponent(new Cmp_Interactable(Interactable::Chest));
	std::unique_ptr<Script> cs = std::make_unique<DropChestScript>(chest, button, global, global2);
	chest->addComponent(new ScriptComponent(std::move(cs)));
	chest->addComponent(new HeadNodeComponent());
	chest->refresh();

	return chest;
}

artemis::Entity* spawnButton(glm::vec3 pos)
{
	auto* button = SCENE.LoadPrefab(active_directory + "Prefabs/Button.prefab");
	auto* tc = (TransformComponent*)button->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;

	button->addComponent(new Cmp_Interactable(Interactable::Button));
	button->addComponent(new HeadNodeComponent());
	button->refresh();
	return button;
}

artemis::Entity* spawnBatteryHolder(glm::vec3 pos, bool withBattery)
{
	auto* batteryTab = SCENE.LoadPrefab(active_directory + "Prefabs/BatteryHolder.prefab");
	auto* tc = (TransformComponent*)batteryTab->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;

	if (withBattery == true) {
		auto* battery = SCENE.LoadPrefab(active_directory + "Prefabs/Battery.prefab");
		auto* batttc = (TransformComponent*)battery->getComponent<TransformComponent>();
		batttc->local.position = tc->local.position;
		batttc->world[3] = tc->local.position;
		battery->addComponent(new HeadNodeComponent());
		battery->refresh();

		//if you have time, rotate the children of the tc as well
	}

	batteryTab->addComponent(new Cmp_Interactable(Interactable::Button));
	batteryTab->addComponent(new HeadNodeComponent());
	batteryTab->refresh();
	return batteryTab;
}

artemis::Entity* spawnRockFallButton(glm::vec3 pos, glm::vec3 areaCenter, glm::vec3 areaExtents)
{
	auto* pad = SCENE.LoadPrefab(active_directory + "Prefabs/RockFallPad.prefab");
	auto* tc = (TransformComponent*)pad->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;

	auto* cmpinna = new Cmp_Interactable(Interactable::StepOn);
	cmpinna->distance = 2.f;

	pad->addComponent(cmpinna);
	std::unique_ptr<Script> ps = std::make_unique<RockFallScript>(pad, areaCenter, areaExtents);
	pad->addComponent(new ScriptComponent(std::move(ps)));
	pad->addComponent(new HeadNodeComponent());
	pad->refresh();

	return pad;
}

artemis::Entity* spawnShinyBlock(glm::vec3 pos)
{
	auto* block = SCENE.LoadPrefab(active_directory + "Prefabs/ShinyBlock.prefab");
	auto* tc = (TransformComponent*)block->getComponent<TransformComponent>();
	auto* cc = (CollisionComponent*)block->getComponent<CollisionComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;
	cc->mass = 0.3f;

	block->addComponent(new HeadNodeComponent());
	block->refresh();

	return block;
}

artemis::Entity* spawnPowerUp(glm::vec3 pos)
{
	auto* powerup = SCENE.LoadPrefab(active_directory + "Prefabs/UltraSwagStinct.prefab");
	auto* tc = (TransformComponent*)powerup->getComponent<TransformComponent>();

	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;

	std::unique_ptr<Script> ts = std::make_unique<HeartScript>(powerup);
	powerup->addComponent(new ScriptComponent(std::move(ts)));

	powerup->addComponent(new Cmp_Collectible(Collectible::Power));
	powerup->addComponent(new HeadNodeComponent());
	powerup->refresh();
	return nullptr;
}

artemis::Entity* spawnSword(glm::vec3 pos)
{
	artemis::Entity* sword = SCENE.LoadPrefab(active_directory + "Prefabs/sword.prefab");
	auto* tc = (TransformComponent*)sword->getComponent<TransformComponent>();
	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;
	sword->refresh();

	return sword;
}

artemis::Entity* spawnSwitch(glm::vec3 pos)
{
	artemis::Entity* switch_object = SCENE.LoadPrefab(active_directory + "Prefabs/switch_object.prefab");
	auto* tc = (TransformComponent*)switch_object->getComponent<TransformComponent>();
	tc->local.position = glm::vec4(pos, 1.f);
	tc->world[3] = tc->local.position;
	switch_object->refresh();

	return switch_object;
}
