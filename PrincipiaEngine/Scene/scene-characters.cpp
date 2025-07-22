#include "../sam-pch.h"
#include "scene-characters.h"

#include "../Utility/componentIncludes.h"
#include "../Utility/game-component-flags.h"
#include "../Utility/game-resource-manager.h"
#include "../Utility/debug-component.hpp"
#include "../Gameplay/Components/movement-component.h"
#include "../Gameplay/Components/chracterRotationComponent.h"
#include "../Gameplay/Components/attack-component.h"
#include "../Gameplay/Components/enemy-ai-component.h"
#include "../Gameplay/Components/stats-component.h"

#include "../Scripts/pipes-script.h"


artemis::Entity* spawnFroku(MainCharacterData* MainCharacterData)
{
	artemis::Entity* froku = nullptr;
	froku = SCENE.LoadPrefab(active_directory + "Prefabs/Froku.prefab");

	//NodeComponent* nc = SCENE.parents[SCENE.parents.size() - 1];
	NodeComponent* nc = (NodeComponent*)froku->getComponent<NodeComponent>();
	nc->isParent = true;
	SCENE.insertController(nc);
	auto* cc = new Cmp_Character(GAMERESOURCES.get_all_character_states("Froku"));
	auto* mc = new Cmp_Movement();

	cc->prefabName = xxh::xxhash<32, char>("Froku");
	froku->addComponent(cc);
	froku->addComponent(mc);
	MainCharacterData->created(mc, cc);
	froku->addComponent(new CharacterRotationComponent(RotationDir::down));
	TransformComponent* tc = (TransformComponent*)froku->getComponent<TransformComponent>();
	tc->local.position.x = MainCharacterData->pos.x;
	tc->local.position.y = MainCharacterData->pos.y;
	tc->local.position.z = MainCharacterData->pos.z;
	tc->world[3] = tc->local.position;
	auto* col = new CollisionComponent(tc->local.position, glm::vec4(.8f, .25f, .25f, 1.f), CollisionType::Capsule);
	col->mass = 0.1f;
	froku->addComponent(col);
	std::unique_ptr<TestScript> ts = std::make_unique<TestScript>(froku);
	//froku->addComponent(new ScriptComponent(ts.get()));// new TestScript()));

	//Add Animations
	BFGraphComponent* bfg = new BFGraphComponent();
	flatten(bfg, nc);
	froku->addComponent(bfg);
	//froku->addComponent(new AnimationComponent(1, "Froku", "idleStart", AnimFlags(0, 1, 1, 0)));
	froku->addComponent(new AnimationComponent(2, "Froku", "idleStart", "idleEnd", AnimFlags(0, 1, 1, 1)));
	froku->addComponent(new Cmp_Attack());
	froku->addComponent(new HeadNodeComponent());
	froku->addComponent(new Cmp_Stats(100, 1000, 25, 10, .75f));
	froku->addComponent(new AudioComponent(active_directory + "Audio/hitHurt.wav"));
	froku->addComponent(new Cmp_Debug());
	nc->gameFlags |= GameFlag::Movement;
	froku->refresh();

	//add a sword
	artemis::Entity* sword = SCENE.LoadPrefab(active_directory + "Prefabs/sword.prefab");
	auto* hand = (NodeComponent*)bfg->nodes[17];
	auto* swordNode = (NodeComponent*)sword->getComponent<NodeComponent>();
	auto* handTrans = (TransformComponent*)bfg->nodes[17]->data->getComponent<TransformComponent>();
	auto* swordTrans = (TransformComponent*)sword->getComponent<TransformComponent>();

	swordTrans->local.position = glm::vec4(0, 2.f, 0, 0);// handTrans->local.position;
	SCENE.makeChild(swordNode, hand, SCENE.parents);

	auto new_sword_trans = TransformComponent(
		glm::vec3(0, 0, -2.25f),
		glm::vec3(0, 0, 90),
		glm::vec3(10)
	);
	*swordTrans = new_sword_trans;
	//swordTrans->eulerRotation.x = -270.f;
	//swordTrans->local.position = glm::vec4(4.f, -4.f, 10.f, 0.f);
	//swordTrans->world[3] = swordTrans->local.position;
	return froku;
}

artemis::Entity* spawnEnemy(glm::vec3 pos, glm::vec3 rot, std::string name, std::string prefab)
{
	//std::cout << "enemy spawned: " << name;
	artemis::Entity* enemy = SCENE.LoadPrefab(active_directory + "Prefabs/" + prefab + ".prefab");
	auto* nc = (NodeComponent*)enemy->getComponent<NodeComponent>();
	auto* tc = (TransformComponent*)enemy->getComponent<TransformComponent>();
	auto new_trans = TransformComponent(pos, rot, tc->local.scale);
	*tc = new_trans;
	nc->isParent = true;
	nc->name = name;
	auto* bfg = new BFGraphComponent();
	flatten(bfg, nc);
	enemy->addComponent(bfg);
	enemy->addComponent(new HeadNodeComponent());

	enemy->addComponent(new CharacterRotationComponent(RotationDir::up));
	enemy->addComponent(new Cmp_EnemyAI());
	enemy->addComponent(new Cmp_Movement());
	enemy->addComponent(new Cmp_Stats());
	enemy->addComponent(new AudioComponent(active_directory + "Audio/menu.wav"));
	auto* col = (CollisionComponent*)enemy->getComponent<CollisionComponent>();
	if (col == nullptr)
		enemy->addComponent(new CollisionComponent(tc->local.position, tc->local.scale, CollisionType::Box, 0.1f));

	//if (prefab == "DarkFroku") {
	//	auto* ac = new AnimateComponent(1, "Dark")

	//}

	enemy->refresh();
	return enemy;
}

artemis::Entity* spawnEnemyAnim(glm::vec3 pos, glm::vec3 rot, std::string name, std::string prefab)
{
	//std::cout << "enemy spawned: " << name;
	artemis::Entity* enemy = SCENE.LoadPrefab(active_directory + "Prefabs/" + prefab + ".prefab");
	auto* nc = (NodeComponent*)enemy->getComponent<NodeComponent>();
	auto* tc = (TransformComponent*)enemy->getComponent<TransformComponent>();
	auto new_trans = TransformComponent(pos, rot, tc->local.scale);
	*tc = new_trans;
	nc->isParent = true;
	nc->name = name;
	auto* bfg = new BFGraphComponent();
	flatten(bfg, nc);
	enemy->addComponent(bfg);
	if (RESOURCEMANAGER.has_pose(prefab.c_str()))
		enemy->addComponent(new AnimationComponent(.5f, 2, prefab.c_str(), "walkStart", "walkEnd", AnimFlags(0, 1, 0, 0)));
	enemy->addComponent(new HeadNodeComponent());
	enemy->addComponent(new CharacterRotationComponent(RotationDir::left));
	enemy->addComponent(new Cmp_EnemyAI());
	enemy->addComponent(new Cmp_Movement());
	enemy->addComponent(new Cmp_Stats());
	enemy->addComponent(new Cmp_Debug());
	//enemy->addComponent(new AudioComponent(active_directory + "Audio/menu.wav"));
	auto* col = (CollisionComponent*)enemy->getComponent<CollisionComponent>();
	if (col == nullptr)
		enemy->addComponent(new CollisionComponent(tc->local.position, tc->local.scale, CollisionType::Box, .1f));

	//if (prefab == "DarkFroku") {
	//	auto* ac = new AnimateComponent(1, "Dark")

	//}

	enemy->refresh();
	return enemy;
}

artemis::Entity* spawnSnake()
{
	artemis::Entity* snake = SCENE.LoadPrefab(active_directory + "Prefabs/snake.prefab");
	auto tc = (TransformComponent*)snake->getComponent<TransformComponent>();
	//tc->local.position = pos;
	NodeComponent* nc = (NodeComponent*)snake->getComponent<NodeComponent>();
	nc->isParent = true;
	snake->addComponent(new HeadNodeComponent());
	BFGraphComponent* bfg = new BFGraphComponent();
	flatten(bfg->nodes, nc);
	snake->addComponent(bfg);
	//AnimationComponent* ac = new AnimationComponent(1, "Snake", "Slither", AnimFlags(0, 1, 0, 0));
	AnimationComponent* ac = new AnimationComponent(1, "Snake", "Eat", AnimFlags(0, 1, 0, 0));
	//AnimationComponent* ac = new AnimationComponent(2, "Snake", "Eat", "Slither", AnimFlags(0, 1, 1, 0));

	snake->addComponent(new CollisionComponent(tc->local.position, tc->local.scale, CollisionType::Box));
	//snake->addComponent(new Cmp_Interactable(Interactable::Button));
	snake->addComponent(ac);
	snake->refresh();

	return snake;
}

std::vector<artemis::Entity*> FindEnemies()
{
	std::vector<artemis::Entity*> ret;
	for (auto* p : SCENE.parents) {
		auto* node = (NodeComponent*)p->data->getComponent<NodeComponent>();
		if (node != nullptr) {
			auto name = node->name.substr(0, 5);
			if (name == "Enemy")
				ret.push_back(node->data);
		}
	}
	return ret;
}

std::vector<artemis::Entity*> SpawnEnemies()
{
	auto enemies = FindEnemies();
	std::vector<artemis::Entity*> new_enemies;
	new_enemies.reserve(4);
	new_enemies.emplace_back(SCENE.LoadPrefab(active_directory + "Prefabs/Ghost.prefab"));
	new_enemies.emplace_back(SCENE.LoadPrefab(active_directory + "Prefabs/GhostRed.prefab"));
	new_enemies.emplace_back(SCENE.LoadPrefab(active_directory + "Prefabs/GhostGreen.prefab"));
	new_enemies.emplace_back(SCENE.LoadPrefab(active_directory + "Prefabs/GhostBlue.prefab"));

	int i = 0;
	for (auto* enemy : enemies) {
		auto* tc = (TransformComponent*)new_enemies[i]->getComponent<TransformComponent>();
		auto* trans = (TransformComponent*)enemy->getComponent<TransformComponent>();
		auto old_enemy_tc = *trans;
		old_enemy_tc.local.position.y += .5f;

		new_enemies[i]->addComponent(new Cmp_EnemyAI());
		new_enemies[i]->addComponent(new CharacterRotationComponent(RotationDir::up));
		//col->mass = 0.1f;
		old_enemy_tc = *trans;
		*tc = old_enemy_tc;
		tc->TRM[3] = old_enemy_tc.local.position;

		new_enemies[i]->addComponent(new CollisionComponent(old_enemy_tc.local.position, old_enemy_tc.local.scale, Principia::CollisionType::Sphere));
		trans->TRM[3] = trans->local.position;
		//enemy->addComponent(new HeadNodeComponent());
		new_enemies[i]->refresh();
		i++;
	}

	//for (auto* e : enemies) {
	//	auto* n = (NodeComponent*)e->getComponent<NodeComponent>();
	//	SCENE.deleteNode(n);
	//	//e->remove();
	//}
	return new_enemies;
}
