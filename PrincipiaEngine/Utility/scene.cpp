#pragma once
#include "pch.h"
#include "scene.h"
#include "../tinyxml2/tinyxml2.h"
#include "../Rendering/renderSystem.h"
#include "../Rendering/Components/renderComponents.hpp"
#include "../Physics/Components/dynamicComponent.h"
#include "../Physics/Components/staticComponent.h"
//#include "../Utility/serialize-node.h"
#include "../Utility/serialize-sam-node.h"
#include "../Utility/game-component-flags.h"
#include "../Gameplay/Components/character-component.hpp"
#include <stb_image.h>
#include "cast.h"

#ifndef XMLCheckResult
#define XMLCheckResult(a_eResult) if (a_eResult != tinyxml2::XML_SUCCESS) { printf("Error: %i\n", a_eResult); return a_eResult; }
#endif

void Scene::init(artemis::World& w) {

	world = &w;
	em = world->getEntityManager();
	SERIALIZENODE.SetEntityManager(em);
	SERIALIZENODE.SetGameData(new SerializeSAMNode());
	sm = world->getSystemManager();
	rs = (RenderSystem*)sm->getSystem<RenderSystem>();
	ts = (TransformSystem*)sm->getSystem<TransformSystem>();
	as = (AnimationSystem*)sm->getSystem<AnimationSystem>();



	bvh = (BvhSystem*)sm->setSystem(new BvhSystem());
	bvh->initialize();

	colsys = (Principia::CollisionSystem*)sm->setSystem(new Principia::CollisionSystem());
	colsys->initialize();


	//dir = "../Assets/Levels/1_Jungle/Scenes/";

	//LoadScene("Empty");
	//LoadScene("PrefabMaker");

	//LoadScene("Arena");


	
	//LoadScene("Level1/QuadsTest");
	//LoadScene("Beginning");
	//LoadScene("Scene3");
	//LoadScene("testlvl5");

};

void Scene::doStuff() {
	//rs->addNodes(parents);

	//ui->setActiveNode(parents[0]);
	//cc->camera.transform = (TransformComponent*)parents[0]->data->getComponent<TransformComponent>();
	//cc->camera.component = (CameraComponent*)parents[0]->data->getComponent<CameraComponent>();

	//for(NodeComponent* node : parents) {
	//	//ts->recursiveTransform(node);
	//	
	//	if (node->engineFlags & COMPONENT_RIGIDBODY)
	//		insertRigidBody(node);
	//	if (node->engineFlags & COMPONENT_CCONTROLLER)
	//		insertController(node);
	//	if (node->engineFlags & COMPONENT_BUTTON) {
	//		node->data->refresh();
	//		//button->change(*node->data);
	//		//input->change(*node->data);
	//		insertRigidBody(node->children[0]);
	//	}
	//	if (node->engineFlags & COMPONENT_GUI && node->gameFlags == 8) {
	//		GUINumberComponent* gnc = (GUINumberComponent*)node->data->getComponent<GUINumberComponent>();
	//		rs->addGuiNumber(gnc);
	//	}
	//}

	//rs->buildBVH();
}

void Scene::buildBVH()
{
	bvh->rebuild = true;
	bvh->build();
	rs->getComputeRaytracer()->UpdateBVH(bvh->get_ordered_prims(), bvh->get_original_prims(), bvh->get_root(), bvh->get_num_nodes());
	//rs->process();
	//topLevelBVH.build(SplitMethod::Middle, TreeType::Recursive, objectComps, objects);
}

#pragma region Creation Functions
void Scene::createModel(rModel resource, std::string name, glm::vec3 pos, glm::vec3 rot, glm::vec3 sca, bool dynamic) {

	//Add Mesh Component and make it a parent node
	artemis::Entity* entity = &em->create();
	TransformComponent* parentTransform = new TransformComponent(pos, rot, sca);
	NodeComponent* parent = new NodeComponent(entity, name, COMPONENT_MODEL | COMPONENT_TRANSFORM | COMPONENT_AABB);// | COMPONENT_PRIMITIVE);

	parent->isDynamic = dynamic; 
	parent->isParent = true;
	entity->addComponent(parent);
	entity->addComponent(parentTransform);
	//entity->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
	
	entity->refresh();
	
	//set up the subsetsx
	int i = 0;
	for (std::vector<rMesh>::const_iterator itr = resource.meshes.begin(); itr != resource.meshes.end(); itr++) {

		//Create Entity
		artemis::Entity* child = &em->create();

		//Set up subset data
		NodeComponent* childNode = new NodeComponent(child, parent);
		TransformComponent* childTransform = new TransformComponent(resource.meshes[i].center, resource.meshes[i].extents);

		child->addComponent(childNode);
		child->addComponent(childTransform);

		child->addComponent(new MeshComponent(resource.uniqueID, i));
		child->addComponent(new PrimitiveComponent(resource.uniqueID + i));
		child->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
		child->addComponent(new MaterialComponent(0));
		//child->addComponent(new AABBComponent());	//SubsetAABB's point to the rendering system


		//childTransform->parentSM = &parentTransform->scaleM;
		//childTransform->parentRM = &parentTransform->rotationM;
		//childTransform->parentPM = &parentTransform->positionM;

		childNode->name = resource.meshes[i].name;// "Child " + std::to_string(i);
		childNode->engineFlags |= COMPONENT_MESH | COMPONENT_MATERIAL | COMPONENT_AABB | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE;
		parent->children.push_back(childNode);

		++i;
		child->refresh();
		//rs->addNode(childNode);
		//rs->change(*child);
	}
	for (i = 0; i < resource.shapes.size(); ++i) {
		//Create Entity
		artemis::Entity* child = &em->create();

		//Set up subset data
		NodeComponent* childNode = new NodeComponent(child, parent);
		TransformComponent* childTransform = new TransformComponent(resource.shapes[i].center, resource.shapes[i].extents);

		child->addComponent(childNode);
		child->addComponent(childTransform);
		child->addComponent(new PrimitiveComponent(resource.shapes[i].type));
		child->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
		child->addComponent(new MaterialComponent(0));
		//child->addComponent(new AABBComponent()); //will this even be used???

		childNode->name = resource.shapes[i].name;
		childNode->engineFlags |= COMPONENT_MATERIAL | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE;
		parent->children.push_back(childNode);
		
		child->refresh();
		//rs->addNode(childNode);
		//rs->change(*child);
	}

	//rs->addNode(parent);
	//rs->change(*entity);
	rs->updateObjectMemory();
	parents.push_back(parent);
	//ts->recursiveTransform(parent);

	//if its animatable....
	//if (resource.skeletonID > 0) {
	//	parent->engineFlags |= COMPONENT_SKINNED;
	//	rSkeleton* skelly = nullptr;
	//	skelly = &RESOURCEMANAGER.getSkeletonID(resource.skeletonID);
	//	if (skelly != nullptr) {
	//		AnimationComponent* anim = new AnimationComponent(resource.skeletonID);
	//		anim->skeleton.index = RESOURCEMANAGER.getSkeletonIndex(skelly->id);
	//		for (int i = 0; i < skelly->joints.size(); ++i) {
	//			Joint j;
	//			j.parentIndex = skelly->joints[i].parentIndex;
	//			j.invBindPose = skelly->joints[i].invBindPose;
	//			j.transform = skelly->joints[i].transform;
	//			anim->skeleton.joints.push_back(j);
	//		}
	//		anim->channels.resize(anim->skeleton.joints.size());
	//		entity->addComponent(anim);
	//		entity->refresh();
	//		as->change(*entity);
	//	}
	//}
}

void Scene::attachModel(artemis::Entity* entity, std::string name)
{
	auto* parent = (NodeComponent*)entity->getComponent<NodeComponent>();
	auto resource = RESOURCEMANAGER.getModel(name);
	int i = 0;
	for (std::vector<rMesh>::const_iterator itr = resource.meshes.begin(); itr != resource.meshes.end(); itr++) {

		//Create Entity
		artemis::Entity* child = &em->create();

		//Set up subset data
		NodeComponent* childNode = new NodeComponent(child, parent);
		TransformComponent* childTransform = new TransformComponent(resource.meshes[i].center, resource.meshes[i].extents);

		child->addComponent(childNode);
		child->addComponent(childTransform);

		child->addComponent(new MeshComponent(resource.uniqueID, i));
		child->addComponent(new PrimitiveComponent(resource.uniqueID + i));
		child->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
		child->addComponent(new MaterialComponent(0));
		//child->addComponent(new AABBComponent());	//SubsetAABB's point to the rendering system


		//childTransform->parentSM = &parentTransform->scaleM;
		//childTransform->parentRM = &parentTransform->rotationM;
		//childTransform->parentPM = &parentTransform->positionM;

		childNode->name = resource.meshes[i].name;// "Child " + std::to_string(i);
		childNode->engineFlags |= COMPONENT_MESH | COMPONENT_MATERIAL | COMPONENT_AABB | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE;
		parent->children.push_back(childNode);

		++i;
		child->refresh();
		//rs->addNode(childNode);
		//rs->change(*child);
	}
	for (i = 0; i < resource.shapes.size(); ++i) {
		//Create Entity
		artemis::Entity* child = &em->create();

		//Set up subset data
		NodeComponent* childNode = new NodeComponent(child, parent);
		TransformComponent* childTransform = new TransformComponent(resource.shapes[i].center, resource.shapes[i].extents);

		child->addComponent(childNode);
		child->addComponent(childTransform);
		child->addComponent(new PrimitiveComponent(resource.shapes[i].type));
		child->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
		child->addComponent(new MaterialComponent(0));
		//child->addComponent(new AABBComponent()); //will this even be used???

		childNode->name = resource.shapes[i].name;
		childNode->engineFlags |= COMPONENT_MATERIAL | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE;
		parent->children.push_back(childNode);

		child->refresh();
		//rs->addNode(childNode);
		//rs->change(*child);
	}

}
artemis::Entity* Scene::createEmptyObject(std::string name, glm::vec3 pos, glm::vec3 rot, glm::vec3 sca)
{
	artemis::Entity* e = &em->create();
	NodeComponent* parent = new NodeComponent(e, name, COMPONENT_TRANSFORM);
	e->addComponent(parent);
	e->addComponent(new TransformComponent(pos, rot, sca));
	parents.push_back(parent);
	e->refresh();

	return e;
}


//Types: SPHERE = -1, BOX = -2, CYLINDER = -3, PLANE = -4, DISK = -5 ALTHOUGH... WHY ARE THEY POSITIVES???
artemis::Entity* Scene::createShape(std::string name, glm::vec3 pos, glm::vec3 scale, int matID, int type, bool dynamic)
{
	artemis::Entity* e = &em->create();
	NodeComponent*		parent = new NodeComponent(e, name, COMPONENT_MATERIAL | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE);
	TransformComponent* trans  = new TransformComponent(pos, glm::vec3(0.f), scale);
	if(type == 1)
		e->addComponent(new CollisionComponent(trans->local.position, trans->local.scale, CollisionType::Sphere));
	if(type == 2)
		e->addComponent(new CollisionComponent(trans->local.position, trans->local.scale, CollisionType::Box));
	if (type == 3)
		e->addComponent(new CollisionComponent(trans->local.position, trans->local.scale, CollisionType::Capsule));
	dynamic ? e->addComponent(new DynamicComponent()) : e->addComponent(new StaticComponent());
	e->addComponent(new PrimitiveComponent(-type));
	e->addComponent(new MaterialComponent(matID));
	e->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
	e->addComponent(trans);
	e->addComponent(parent);

	parent->isDynamic = dynamic;
	e->refresh();
	//rs->addNode(parent);
	parents.push_back(parent);
	ts->recursiveTransform(parent);
	rs->updateObjectMemory();

	return e;
}
artemis::Entity* Scene::createGameShape(std::string name, glm::vec3 pos, glm::vec3 scale, int matID, int type, bool dynamic)
{
	artemis::Entity* e = &em->create();
	NodeComponent*		parent = new NodeComponent(e, name, COMPONENT_MATERIAL | COMPONENT_TRANSFORM | COMPONENT_PRIMITIVE);
	TransformComponent* trans = new TransformComponent(pos, glm::vec3(0.f), scale); 
	//if (type == 3)
	// 	e->addComponent(new CollisionComponent(trans->local.position, trans->local.scale, CollisionType::Box));

	e->addComponent(new PrimitiveComponent(-type));
	e->addComponent(new MaterialComponent(matID));
	e->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
	e->addComponent(new HeadNodeComponent());
	e->addComponent(trans);
	e->addComponent(parent);

	parent->isDynamic = dynamic;
	parent->isParent = true;
	e->refresh();
	//rs->addNode(parent);
	ts->recursiveTransform(parent);
	//rs->updateObjectMemory();

	parents.push_back(parent);
	return e;
}

void Scene::insertController(NodeComponent * nc)
{
	int cid = 1;
	if (pINPUT.hasGamepad) cid = 1;
	if(!(nc->gameFlags & GameFlag::Controller)){
		nc->engineFlags |= GameFlag::Controller;
		nc->data->addComponent(new Cmp_Character());
		nc->data->addComponent(new ControllerComponent(cid));
	}

	ControllerComponent* controller = (ControllerComponent*)nc->data->getComponent<ControllerComponent>();
	for (int i = 0; i < NUM_BUTTONS; ++i) {
		controller->buttons[i].key = RESOURCEMANAGER.getConfig().controllerConfigs[controller->index].buttons[i];
		for (int i = 0; i < 6; ++i)
			controller->axis_buttons[i].key = to_int(RESOURCEMANAGER.getConfig().controllerConfigs[controller->index].axis[i]);
		
	}

	nc->data->refresh();
	//input->change(*nc->data);
	
	//cc->change(*nc->data);
	//cc->characterTransform = (TransformComponent*)nc->data->getComponent<TransformComponent>();
	//cc->characterNode = nc;

	//sets up the singleton to also use this controller
	if (controller->index == 1) {
		ControllerComponent* scomp = new ControllerComponent(controller);
		world->getSingleton()->addComponent(scomp);
		world->getSingleton()->refresh();
		//input->change(*world->getSingleton());
	}
	else {
		ControllerComponent* scomp = new ControllerComponent(1);
		for (int i = 0; i < NUM_BUTTONS; ++i) {
			scomp->buttons[i].key = RESOURCEMANAGER.getConfig().controllerConfigs[1].buttons[i];
			if (i < 6)
				scomp->axis_buttons[i].key = to_int(RESOURCEMANAGER.getConfig().controllerConfigs[1].axis[i]);
		}
		world->getSingleton()->addComponent(scomp);
		world->getSingleton()->refresh();
	}

}

void Scene::insertRigidBody(NodeComponent* nc) {
	if(!(nc->engineFlags & COMPONENT_RIGIDBODY))
	nc->engineFlags |= COMPONENT_RIGIDBODY;
	TransformComponent* tc = (TransformComponent*)nc->data->getComponent<TransformComponent>();

	//nc->data->addComponent(new RigidBodyComponent(1.f, tc->world));
	//nc->data->refresh();
	//ps->change(*nc->data);
	//ps->addNode(nc);

	if (nc->engineFlags & COMPONENT_COLIDER) {
		//nc->data->addComponent(new CollisionComponent());
		//nc->data->refresh();
		//cc->change(*nc->data);
	}
}

void Scene::insertGoal(artemis::Entity & e)
{

}

artemis::Entity* Scene::createLight() {//glm::vec3 pos, glm::vec3 color, float intensity) {
	artemis::Entity* e = &em->create();

	e->addComponent(new LightComponent());
	e->addComponent(new RenderComponent(RenderType::RENDER_LIGHT));
	//LightComponent* l = new LightComponent();
	//l->color = color;
	//l->intensity = intensity;

	e->addComponent(new TransformComponent(glm::vec3(0.f), glm::vec3(0.f), glm::vec3(0.f)));
	e->addComponent(new NodeComponent(e));
	//ui->addParentEntity(e, "Light");
	NodeComponent* parent = (NodeComponent*)e->getComponent<NodeComponent>();
	parent->name = "Light";
	parent->engineFlags |= COMPONENT_LIGHT | COMPONENT_TRANSFORM;
	parents.push_back(parent);

	return e;

}

artemis::Entity* Scene::createCamera() {// glm::vec3 pos) {
	artemis::Entity* e = &em->create();

	e->addComponent(new CameraComponent(1.6f, 60.f));
	e->addComponent(new RenderComponent(RenderType::RENDER_CAMERA));
	e->addComponent(new TransformComponent(glm::vec3(0), glm::vec3(0.f), glm::vec3(0.f)));
	e->addComponent(new NodeComponent(e));
	//ui->addParentEntity(e, "Camera");
	NodeComponent* parent = (NodeComponent*)e->getComponent<NodeComponent>();
	parent->name = "Camera";
	parent->engineFlags |= COMPONENT_CAMERA | COMPONENT_TRANSFORM;
	parents.push_back(parent);

	return e;
}


#pragma endregion functions for creating things and scenifying them

void Scene::deleteNode(std::vector<NodeComponent*>& nParents, int nIndex)
{
	NodeComponent* parent = nParents[nIndex];
	//First delete all children if haz childrenz
	if (parent->children.size() > 0)
		deleteAllChildren(parent);
	//delete stuff 
	//rs->deleteNode(parent);
	em->remove(*parent->data);
	nParents.erase(nParents.begin() + nIndex);	
	rs->updateObjectMemory();
}
void Scene::deleteNode(NodeComponent* parent) {
	//delete stuff 
	//rs->deleteNode(parent);
	if (parent->children.size() > 0)
		deleteAllChildren(parent);
	em->remove(*parent->data);
	parent->needsDelete = true;
	std::erase_if(parents, [parent](NodeComponent* p) { return p == parent; });
	//nParents.erase(nParents.begin() + nIndex);
	rs->updateObjectMemory();
}

void Scene::deleteNode(artemis::Entity & e)
{
	NodeComponent* nc = (NodeComponent*)e.getComponent<NodeComponent>();
	em->remove(*nc->data);
	
	//YOURE GONAN HAVE A LOT OF USELESS PARENTS ithink


}

void Scene::copyNode(NodeComponent * node, NodeComponent* parent, std::vector<NodeComponent*>& list)
{
	//create entity
	artemis::Entity* e = &em->create();

	//auto comps = e->getComponents();
	//auto numComps = comps.getCount();
	//comps.get(0);
	//e->getComponent<TransformComponent>();
	//e->removeComponent<TransformComponent>();

	
	//create new node
	e->addComponent(new NodeComponent(e, parent, *node));
	NodeComponent* copy = (NodeComponent*)e->getComponent<NodeComponent>();

	//copy all the datas
	if (node->engineFlags & COMPONENT_TRANSFORM) {
		e->addComponent(new TransformComponent(*(TransformComponent*)node->data->getComponent<TransformComponent>()));
	}
	else { //if this is gonna be a parent, it must have a transform componenet... right?
		if (parent == nullptr) {
			if (node->parent->data->getComponent<TransformComponent>() != nullptr)
				e->addComponent(new TransformComponent(*(TransformComponent*)node->parent->data->getComponent<TransformComponent>()));
			else
				e->addComponent(new TransformComponent(glm::vec3(0.f), glm::vec3(0.f), glm::vec3(1.f)));
			copy->engineFlags |= COMPONENT_TRANSFORM;
		}
	}
	if (node->engineFlags & COMPONENT_MATERIAL) {
		e->addComponent(new MaterialComponent(*(MaterialComponent*)node->data->getComponent<MaterialComponent>()));
		e->addComponent(new RenderComponent(RenderType::RENDER_PRIMITIVE));
	}
	if (node->engineFlags & COMPONENT_LIGHT) {
		e->addComponent(new LightComponent(*(LightComponent*)node->data->getComponent<LightComponent>()));
		e->addComponent(new RenderComponent(RenderType::RENDER_LIGHT));
		//TODO: INVESTIGATE IF NEEDED, SAME FOR MATERIAL
	}
	if (node->engineFlags & COMPONENT_PRIMITIVE) {
		e->addComponent(new PrimitiveComponent(*(PrimitiveComponent*)node->data->getComponent<PrimitiveComponent>()));
	}
	if (node->engineFlags & COMPONENT_AABB) {
		//e->addComponent(new AABBComponent(*(AABBComponent*)node->data->getComponent<AABBComponent>()));
	}
	if (node->engineFlags & COMPONENT_RIGIDBODY) {
		insertRigidBody(copy);
	}

	if (node->engineFlags & COMPONENT_COLIDER) {
		e->addComponent(new CollisionComponent(*(CollisionComponent*)node->data->getComponent<CollisionComponent>()));
	}

	//add the children
	if (node->children.size() > 0) {
		for (NodeComponent* child : node->children)
		{
			copyNode(child, copy, copy->children);
		}
	}

	ts->recursiveTransform(copy);
	rs->addNode(copy);
	//rs->added();
	list.push_back(copy);
	rs->updateObjectMemory();
	e->refresh();
	//rs->updateMeshMemory();
	
}

void Scene::makeParent(NodeComponent * child)
{
	//Remove it from the parent
	for (auto c = child->parent->children.begin(); c != child->parent->children.end(); c++) {
		if (*c == child) {
			child->parent->children.erase(c);
			break;
		}
	}
	//
	if (!(child->engineFlags & COMPONENT_TRANSFORM)) {
		child->data->addComponent(new TransformComponent(*(TransformComponent*)child->parent->data->getComponent<TransformComponent>()));
		child->engineFlags |= COMPONENT_TRANSFORM;
	}
	//transform back to the thing
	//TransformComponent* c
	child->parent = nullptr;
	parents.push_back(child);
}

//Takes in 1.The Node your making a child 2. The parent of the child 3. The list you're taking it from
void Scene::makeChild(NodeComponent * node, NodeComponent * parent, std::vector<NodeComponent*>& list)
{
	//Remove it from the list you're taking it from
	for (auto c = list.begin(); c != list.end(); c++) {
		if (*c == node) {
			list.erase(c);
			break;
		}
	}

	// add it to the parent
	node->parent = parent;

	//if it has no transform, give it one
	if (!(node->engineFlags & COMPONENT_TRANSFORM)) {
		node->data->addComponent(new TransformComponent(*(TransformComponent*)node->parent->data->getComponent<TransformComponent>()));
		node->engineFlags |= COMPONENT_TRANSFORM;
	}
	else {
		TransformComponent* pt = (TransformComponent*)parent->data->getComponent<TransformComponent>();
		TransformComponent* ct = (TransformComponent*)node->data->getComponent<TransformComponent>();

		auto newPosRot = glm::inverse(pt->TRM) * ct->TRM;
		ct->local.position = newPosRot[3];
		ct->local.rotation = glm::toQuat(newPosRot);
		ct->local.scale = ct->global.scale / pt->global.scale;		
	}
	parent->children.push_back(node);
	ts->recursiveTransform(node);
}

void Scene::updateObject(NodeComponent * node)
{
	if (node->engineFlags & COMPONENT_MESH)
		rs->setRenderUpdate(Renderer::kUpdateMesh);
	if (node->engineFlags & COMPONENT_SPHERE)
		rs->setRenderUpdate(Renderer::kUpdateSphere);
	if (node->engineFlags & COMPONENT_CYLINDER)
		rs->setRenderUpdate(Renderer::kUpdateCylinder);
	if (node->engineFlags & COMPONENT_BOX)
		rs->setRenderUpdate(Renderer::kUpdateBox);
	if (node->engineFlags & COMPONENT_PLANE)
		rs->setRenderUpdate(Renderer::kUpdatePlane);
	if (node->engineFlags & COMPONENT_LIGHT)
		rs->setRenderUpdate(Renderer::kUpdateLight);
}

#pragma region SAVE/LOADSCENE
using namespace tinyxml2;
XMLError Scene::SaveScene()// std::string name)
{
	//First save the directory of the level u iz in
	//"../../Assets/Common/";

	XMLDocument doc;
	XMLError eResult;

	XMLNode * pRoot = doc.NewElement("Root");
	doc.InsertFirstChild(pRoot);
	XMLElement * sceneNumber = doc.NewElement("Scene");
	sceneNumber->SetAttribute("Num", 1);

	pRoot->InsertFirstChild(sceneNumber);

	for(NodeComponent* node : parents)
	{
		node->engineFlags |= COMPONENT_HEADNODE;
		XMLElement* element = SERIALIZENODE.saveNode(node, &doc);
		pRoot->InsertEndChild(element);
	}
	eResult = doc.SaveFile((dir+currentScene+".xml").c_str());
	XMLCheckResult(eResult);
	return eResult;
}

XMLError Scene::LoadScene(std::string name)
{
	currentScene = name;
	XMLDocument doc;
	XMLError eResult = doc.LoadFile((dir+name+".xml").c_str());
	XMLNode * pNode = doc.FirstChild();

	XMLElement* pRoot = doc.FirstChildElement("Root");// ->FirstChildElement("Scene");
	XMLElement* sceneN = pRoot->FirstChildElement("Scene");
	pRoot->FirstChildElement("Scene")->QueryIntAttribute("Num", &sceneNumber); // sceneN->QueryIntAttribute("Num", &sceneNumber);
	
	int a = sceneNumber;


	XMLElement* first = pRoot->FirstChildElement("Node");
	XMLElement* last = pRoot->LastChildElement("Node");
	parents = SERIALIZENODE.loadNodes(first, nullptr);
	
	//for (auto* p : parents) {
	//	p->data->addComponent(new HeadNodeComponent());
	//}

	//ui->setActiveAsCamera();
	return eResult;
}

tinyxml2::XMLError Scene::LoadNewScene(std::string name)
{
	currentScene = name;
	XMLDocument doc;
	XMLError eResult = doc.LoadFile((dir + name + ".xml").c_str());
	XMLNode* pNode = doc.FirstChild();

	XMLElement* pRoot = doc.FirstChildElement("Root");// ->FirstChildElement("Scene");
	XMLElement* sceneN = pRoot->FirstChildElement("Scene");
	pRoot->FirstChildElement("Scene")->QueryIntAttribute("Num", &sceneNumber); // sceneN->QueryIntAttribute("Num", &sceneNumber);

	int a = sceneNumber;


	XMLElement* first = pRoot->FirstChildElement("Node");
	XMLElement* last = pRoot->LastChildElement("Node");
	auto new_parents = SERIALIZENODE.loadNodes(first, nullptr);
	parents.insert(parents.end(), new_parents.begin(), new_parents.end());

	//buildBVH();
	return eResult;
}

artemis::Entity* Scene::LoadPrefab(std::string name)
{
	XMLDocument doc;
	XMLError eResult = doc.LoadFile((name).c_str());
	//XMLCheckResult(eResult);
	XMLNode * pNode = doc.FirstChild();
	XMLElement* pRoot = doc.FirstChildElement("Root");

	artemis::Entity* e = &em->create();

	SERIALIZENODE.loadNode(pRoot->FirstChildElement("Node"), e);

	e->refresh();

	parents.push_back((NodeComponent*)e->getComponent<NodeComponent>());

	return e;// Result;
}

void Scene::AttachPrefabToEntity(std::string name, NodeComponent* nc)
{
	XMLDocument doc;
	XMLError eResult = doc.LoadFile((name).c_str());
	//XMLCheckResult(eResult);
	XMLNode* pNode = doc.FirstChild();
	XMLElement* pRoot = doc.FirstChildElement("Root");

	auto* e = nc->data;

	SERIALIZENODE.loadNode(pRoot->FirstChildElement("Node"), e);

	e->refresh();

	//.push_back((NodeComponent*)e->getComponent<NodeComponent>());

	//return e;// Result;
}

void Scene::AddEntityToScene(artemis::Entity * e)
{
	NodeComponent* nc = (NodeComponent*)e->getComponent<NodeComponent>();
	if (nc)
		parents.push_back(nc);
	else {
		nc = new NodeComponent(e);
		e->addComponent(nc);
		parents.push_back(nc);
	}
}

void Scene::deleteScene()
{
	for (auto p : parents) {
		deleteAllChildren(p);
		//deleteNode(p);
		if(!p->needsDelete)
			em->remove(*p->data);
	}
	parents.clear();
	rs->updateObjectMemory();
}
void Scene::deleteSceneExceptUI()
{
	std::vector<NodeComponent*> newParents;
	for (auto p : parents) {
		auto* uic = (GUIComponent*)p->data->getComponent<GUIComponent>();
		auto* uinc = (GUINumberComponent*)p->data->getComponent<GUINumberComponent>();
		if (uic == nullptr && uinc == nullptr) {
			deleteAllChildren(p);
			if (!p->needsDelete)
				em->remove(*p->data);
		}
		else
			newParents.push_back(p);
	}
	parents.clear();
	parents = newParents;
	rs->updateObjectMemory();
	//colsys.re
}

void Scene::deleteSceneExceptPlayer()
{
	std::vector<NodeComponent*> newParents;
	for (auto p : parents) {
		//auto* uic = (GUIComponent*)p->data->getComponent<GUIComponent>();
		//auto* uinc = (GUINumberComponent*)p->data->getComponent<GUINumberComponent>();
		auto* player = (Cmp_Character*)p->data->getComponent<Cmp_Character>();
		if (player != nullptr) {
			assert(p->name == "Froku");
			newParents.push_back(p);
		}
		else{
			assert(p->name != "Froku");
			deleteAllChildren(p);
			if (!p->needsDelete)
				em->remove(*p->data);
		}
	}
	assert(newParents.size() > 0);
	parents.clear();
	parents = newParents;
	assert(parents.size() > 0);
	rs->updateObjectMemory();
}

/*
Texture Level Creator
	• (0,0) = black
	* (2,1) = white
	• (1,4) = red
	• (4,5) = green
	* (6,7) = blue
*/
void Scene::LoadSceneFromTexture(std::string txtr_file)
{
	PrImage image(txtr_file);
}

//
//tinyxml2::XMLError Scene::SavePrefab(std::string name, NodeComponent* node)
//{
//	XMLDocument doc;
//	XMLError eResult;
//
//	XMLNode * pRoot = doc.NewElement("Root");
//	doc.InsertFirstChild(pRoot);
//
//	XMLElement* element = saveNode(node, &doc);
//	eResult = doc.SaveFile((dir + node->name + ".prefab").c_str());
//
//	XMLCheckResult(eResult);
//}
//
//tinyxml2::XMLError Scene::LoadPrefab(std::string name, NodeComponent* node)
//{
//	currentScene = name;
//	XMLDocument doc;
//	XMLError eResult = doc.LoadFile((dir + name + ".prefab").c_str());
//	XMLNode * pNode = doc.FirstChild();
//
//	XMLElement* pRoot = doc.FirstChildElement("Root");// ->FirstChildElement("Scene");
//	//XMLElement* sceneN = pRoot->FirstChildElement("Scene");
//	//sceneN->QueryIntAttribute("Num", &sceneNumber);
//
//	XMLElement* first = pRoot->FirstChildElement("Node");
//	XMLElement* last = pRoot->LastChildElement("Node");
//	parents = loadNodes(first, last, nullptr);
//
//	//ui->setActiveAsCamera();
//	return eResult;
//}

#pragma endregion these are functions for saving and loading the scene

void Scene::deleteAllChildren(NodeComponent* parent)
{
	for(NodeComponent* child : parent->children)
	{
		//first recursively delete all children before you delete all children
		if(child->children.size() > 0)
			deleteAllChildren(child);

		//remove from rendering
		//rs->deleteNode(child);
		em->remove(*child->data);
	}
	if(parent->children.size() > 0)
		parent->children.clear();
}
