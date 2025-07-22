#pragma once
/*
Scene Copyright (C) by Mike Murrell 
this is where all the scene building goes which means
loading/saving scene, creating/copying/deleting objects
*/


#include "../Utility/resourceManager.h"
#include "../Animation/animationSystem.h"
//#include "script.hpp"
#include "Utility/transformSystem.h"
#include "../Application/controllerSystem.h"
#include "../Gameplay/Components/chracterRotationComponent.h"
#include "../Gameplay/Components/character-component.hpp"
#include "../Audio/audioComponents.h"
#include "../Utility/bvhSystem.h"
#include "../Physics/collisionSystem.h"

using namespace Principia;

#define SCENE Scene::get()


class Scene{ //: public artemis::EntityProcessingSystem {
private:
	Scene() {};
public:
	~Scene() {};
	static Scene& get() {
		static Scene instance;
		return instance;
	}
	Scene(Scene const&) = delete;
	void operator=(Scene const&) = delete;

	artemis::World* world = nullptr;
	artemis::EntityManager* em = nullptr;
	artemis::SystemManager* sm = nullptr;

	RenderSystem* rs = nullptr;
	TransformSystem* ts = nullptr;
	//EngineUISystem* ui;
	AnimationSystem* as = nullptr;

	//CharacterController* cc;
	//ControllerSystem* input;

	std::vector<NodeComponent*> parents = {};
	std::vector<TransformComponent*> transforms = {};

	std::string currentScene = "";

	BvhSystem* bvh = nullptr;
	Principia::CollisionSystem* colsys = nullptr;

	int sceneNumber = 0;
	
	void init(artemis::World& w);

	void doStuff();
	void buildBVH();

	void createModel(rModel resource, std::string name, glm::vec3 pos, glm::vec3 rot, glm::vec3 sca, bool dynamic = true);
	void attachModel(artemis::Entity* entity, std::string name);
	
	artemis::Entity* createEmptyObject(std::string name, glm::vec3 pos, glm::vec3 rot, glm::vec3 sca);
	artemis::Entity* createShape(std::string name, glm::vec3 pos, glm::vec3 scale, int matID, int type, bool dynamic = true);
	artemis::Entity* createGameShape(std::string name, glm::vec3 pos, glm::vec3 scale, int matID, int type, bool dynamic = true);

	void insertController(NodeComponent* nc);
	void insertRigidBody(NodeComponent* nc);
	void insertGoal(artemis::Entity& e);
	artemis::Entity* createLight();

	artemis::Entity* createCamera();

	void deleteNode(std::vector<NodeComponent*>& nParents, int nIndex);
	void deleteNode(NodeComponent* parent);
	void deleteNode(artemis::Entity& e);
	void copyNode(NodeComponent* node, NodeComponent* parent, std::vector<NodeComponent*>& list);
	void makeParent(NodeComponent * child);
	void makeChild(NodeComponent* node, NodeComponent* parent, std::vector<NodeComponent*>& list);

	void updateObject(NodeComponent* node);
	//void addNode(ComponentFlag flags, std::string name, TransformComponent tc, int matID = 0, int meshID = 0);

	tinyxml2::XMLError SaveScene();// std::string name);
	tinyxml2::XMLError LoadScene(std::string name);
	tinyxml2::XMLError LoadNewScene(std::string name);
	artemis::Entity* LoadPrefab(std::string name);
	void AttachPrefabToEntity(std::string name, NodeComponent* nc);
	void AddEntityToScene(artemis::Entity* e);
	void deleteScene();
	void deleteSceneExceptUI();
	void deleteSceneExceptPlayer();
	void LoadSceneFromTexture(std::string txtr_file);
	void set_directory(std::string_view d) { dir = d.data(); };

private:

	void deleteAllChildren(NodeComponent* children);

	std::string dir = "../Assets/Levels/Test/Scenes/";

};