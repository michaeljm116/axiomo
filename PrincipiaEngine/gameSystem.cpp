//#include "pch.h"
#include "gameSystem.h"
#include "../Rendering/renderSystem.h"
#include <thread>

#include "../tinyxml2/tinyxml2.h"

GameSystem::GameSystem()
{
	addComponentType<GameComponent>();
	//addComponentType<ControllerComponent>();
	addComponentType<GameSettingsComponent>();
}

GameSystem::~GameSystem()
{
}

GameSystem::GameSystem(bool s) : immediate_start(s) {
	addComponentType<GameComponent>();
	//addComponentType<ControllerComponent>();
	addComponentType<GameSettingsComponent>();
}

void GameSystem::initialize()
{
	gameMapper.init(*world); 
	settingsMapper.init(*world);
	controllerMapper.init(*world);
	LoadGameSettings(*world->getSingleton());

	em = world->getEntityManager();
	sm = world->getSystemManager();

	controllers = (ControllerSystem*)sm->setSystem(new ControllerSystem());
	controllers->initialize();

	rs = (RenderSystem*)sm->getSystem<RenderSystem>();
	ts = (TransformSystem*)sm->getSystem<TransformSystem>();

	sys_Animation = (AnimationSystem*)sm->setSystem(new AnimationSystem());
	sys_Animate = (AnimateSystem*)sm->setSystem(new AnimateSystem());
	sys_Animation->initialize();
	sys_Animate->initialize();

	sys_CharacterController = (Sys_CharacterController*)sm->setSystem(new Sys_CharacterController);
	sys_CharacterController->initialize();
	sys_Movement = (Sys_Movement*)sm->setSystem(new Sys_Movement());
	sys_Movement->initialize();
	//sys_Attack = (Sys_Attack*)sm->setSystem(new Sys_Attack());
	//sys_Attack->initialize();

	crs = (CharacterRotationSystem*)sm->setSystem(new CharacterRotationSystem());
	crs->initialize();

	//Menus
	title = (TitleSystem*)sm->setSystem(new TitleSystem());
	menu = (MenuSystem*)sm->setSystem(new MenuSystem());
	pause = (PauseSystem*)sm->setSystem(new PauseSystem());
	title->initialize();
	menu->initialize();
	pause->initialize();


	//collision systems
	//sysGrid = (GridSystem*)sm->setSystem(new GridSystem());
	col = (CollisionSystem*)sm->setSystem(new CollisionSystem());
	cws = (CollidedWithSystem*)sm->setSystem(new CollidedWithSystem());
	//sysImmovable = (ImmovableSystem*)sm->setSystem(new ImmovableSystem());
	//sysGravity = (SysGravity*)sm->setSystem(new SysGravity());

	//sysImmovable->initialize();	
	//sysGrid->initialize();
	cws->initialize();
	col->initialize();
	//sysGravity->initialize();

	sys_Scripting = (Sys_Scripting*)sm->setSystem(new Sys_Scripting());
	sys_Scripting->initialize();

	sys_Collectible = (Sys_Collectible*)sm->setSystem(new Sys_Collectible());
	sys_Collectible->initialize();

	sys_Interactable = (Sys_Interactable*)sm->setSystem(new Sys_Interactable());
	sys_Interactable->initialize();

	sys_EnvironmentDamage = (Sys_EnvironmentDamage*)sm->setSystem(new Sys_EnvironmentDamage());
	sys_EnvironmentDamage->initialize();


	//Startup
	gameSceneSys = (GameSceneSystem*)sm->setSystem(new GameSceneSystem());
	gameSceneSys->initialize();

	//button = (ButtonSystem*)sm->getSystem<ButtonSystem>();

	world->getSingleton()->addComponent(new AudioComponent(active_directory + "Audio/death.wav"));
	audio = (AudioSystem*)sm->setSystem(new AudioSystem());
	audio->initialize();
	//world->getSingleton()->addComponent();
	
	if(immediate_start)
	start_up();

}

void GameSystem::start_up()
{
	gameSceneSys->start_up();
	sys_AiMovement = (Sys_AiMovement*)sm->setSystem(new Sys_AiMovement());
	sys_AiMovement->initialize();
	auto* gdc = (GlobalDataComponent*)world->getSingleton()->getComponent<GlobalDataComponent>();
	sys_AiMovement->SetPlayer(gdc->main_character_data.entity);

	sys_AttackEnemy = (Sys_AttackEnemy*)sm->setSystem(new Sys_AttackEnemy());
	sys_AttackPlayer = (Sys_AttackPlayer*)sm->setSystem(new Sys_AttackPlayer());
	sys_AttackEnemy->initialize();
	sys_AttackPlayer->initialize();
	sys_AttackEnemy->set_player(gdc->main_character_data.entity);
	sys_AttackPlayer->set_player(gdc->main_character_data.entity);

	sys_Death = (Sys_Death*)sm->setSystem(new Sys_Death);
	sys_Death->initialize();

	sys_Spawn = (Sys_Spawn*)sm->setSystem(new Sys_Spawn());
	sys_Spawn->initialize();
}

static bool Loaded = false;
static bool show_title = true;
void GameSystem::added(artemis::Entity & e)
{
	if(!Loaded)
	LoadGameSettings(e);
}

void GameSystem::removed(artemis::Entity & e)
{
	SaveGameSettings(e);
}

void GameSystem::processEntity(artemis::Entity & e)
{	
	
	if (show_title)handleTitleMenu(e);
	else {
		handleGamePlay(e);
	}

	//audio->process();
	ControllerComponent* c = controllerMapper.get(e);

	//pause button
	if (c->buttons[GLFW_GAMEPAD_BUTTON_GUIDE].action == 1) {
		//c->buttons[4].action = 0;
		//c->buttons[4].time = 0.f;
		RenderSystem* rs = (RenderSystem*)world->getSystemManager()->getSystem<RenderSystem>();

		for (size_t i = 0; i < goals.size(); ++i) {
			goals[i]->alpha = 0;// visible = false;
			rs->updateGuiNumber(goals[i]);
		}

		e.removeComponent<GameComponent>();
		e.addComponent(new PauseComponent());
		e.refresh();
	}
	//physicsThread.join();
	//cwsThread.join();
}

void GameSystem::findGoals()
{
	int count = world->getEntityManager()->getEntityCount();
	NodeComponent* temp;
	for (int i = 0; i < count; ++i) {
		artemis::Entity &e =  world->getEntity(i);
		temp = (NodeComponent*)e.getComponent<NodeComponent>();
		if (temp != nullptr) {
			if (temp->gameFlags == 8) {
				e.refresh();
				//scorer->change(e);
				GUINumberComponent* g = (GUINumberComponent*)e.getComponent<GUINumberComponent>();
				goals.push_back(g);
			}
		}
	}
}

void GameSystem::sceneChanged(artemis::Entity* e) {
	//sys_Interactable->sceneChanged(e);
}

using namespace tinyxml2;
void GameSystem::LoadGameSettings(artemis::Entity& e)
{
	auto* settings = settingsMapper.get(e);
	XMLDocument doc;
	XMLError e_result = doc.LoadFile((settings->file).c_str());
	XMLNode* p_node = doc.FirstChild();

	XMLElement* p_root = doc.FirstChildElement("Root");// ->FirstChildElement("Scene");
	p_root = p_root->FirstChildElement("GameSettings");
	auto* curr_node = p_root->FirstChildElement("Setting");

	while (curr_node != nullptr) {
		const char* setting_name;
		//int num_parameters = 0;
		curr_node->QueryStringAttribute("name", &setting_name);
		//curr_node->QueryIntAttribute("parameters", &num_parameters);
		auto* parameter_node = curr_node->FirstChildElement("Parameter");
		while (parameter_node != nullptr) {
			GameSetting parameter;
			const char* type;
			const char* param_name;
			parameter_node->QueryStringAttribute("name", &param_name);
			parameter.parameter_name = param_name;
			parameter_node->QueryStringAttribute("type", &type);
			parameter.data_type = 0 + (type == "string");
			parameter_node->QueryFloatAttribute("value", &parameter.value);
			parameter_node = parameter_node->NextSiblingElement();

			settings->settings[setting_name].push_back(parameter);
		}
		curr_node = curr_node->NextSiblingElement("Setting");
	}
	Loaded = true;
	//UpdateGameSettings(e);
}

void GameSystem::SaveGameSettings(artemis::Entity& e)
{
	XMLDocument doc;
	XMLError e_result;
	XMLNode* p_root = doc.NewElement("Root");
	XMLElement* p_game_settings = doc.NewElement("GameSettings");
	doc.InsertFirstChild(p_root);
	auto* settings = settingsMapper.get(e);
	for (const auto& [key, value] : settings->settings) {
		auto* p_setting = doc.NewElement("Setting");
		p_setting->SetAttribute("name", key.c_str());
		for (const auto& p : value) {
			auto* p_parameter = doc.NewElement("Parameter");
			p_parameter->SetAttribute("name", p.parameter_name.c_str());
			std::string type = "float"; if (p.data_type == 1) type = "string";
			p_parameter->SetAttribute("type", type.c_str());
			p_parameter->SetAttribute("value", p.value);
			p_setting->InsertEndChild(p_parameter);
		}
		p_game_settings->InsertEndChild(p_setting);
	}
	p_root->InsertEndChild(p_game_settings);
	e_result = doc.SaveFile(settings->file.c_str());
}

void GameSystem::UpdateGameSettings(artemis::Entity& e)
{
	//auto* settings = settingsMapper.get(e);
	//auto* gdc = (GlobalDataComponent*)e.getComponent<GlobalDataComponent>();
	////auto* physics = (Cmp_Physics*)world->getSingleton()->getComponent<Cmp_Physics>();
	////
	////physics->dynamicsWorld->setGravity(btVector3(0, settings->settings.find("Gravity")->second[0].value, 0));
	////gdc->main_character_data.moveRef->jumpSpeed = settings->settings.find("Speed")->second[1].value;
	////gdc->main_character_data.moveRef->walkSpeed = settings->settings.find("Speed")->second[0].value;
	//gdc->speed.player = settings->settings.find("Speed")->second[0].value;
	//gdc->speed.enemy = settings->settings.find("Speed")->second[1].value;
	//gdc->distance.light = settings->settings.find("Distance")->second[0].value;
	//gdc->distance.camera_y = settings->settings.find("Distance")->second[1].value;
	//gdc->distance.camera_z = settings->settings.find("Distance")->second[2].value;
	//gdc->times.pill = settings->settings.find("Timer")->second[0].value;
	//gdc->times.fruit = settings->settings.find("Timer")->second[1].value;
	//gdc->times.respawn = settings->settings.find("Timer")->second[2].value;
}

void GameSystem::handleStartup(artemis::Entity& e)
{
}

void GameSystem::handleGamePlay(artemis::Entity& e)
{
	controllers->process();

	//flappy_menu->process();

	//sys_Scripting->process(); // Possible multithread
	sys_CharacterController->process();
	sys_AiMovement->process();
	sys_AttackPlayer->process();
	sys_AttackEnemy->process();
	sys_Spawn->process();

	sys_Interactable->process();
	sys_Animation->process(); 
	sys_Animate->process(); // Possible multithread
	sys_Death->process();

	crs->process();
	sys_Movement->process();
		
	col->process(); // Probably multi thread although its last so..
	cws->process();
	ts->process();
	audio->process();
	
}

void GameSystem::handleTitleMenu(artemis::Entity& e)
{
	title->process();
	//sys_Movement->not_dead = 1.f;
	crs->not_dead = true;
 	controllers->process();
	sys_Animation->process();
	sys_Animate->process(); // Possible multithread
	ts->processMulti(); 

	if (e.getComponent<TitleComponent>() == nullptr) {
		show_title = false;
		auto* gui = (GUIComponent*)world->getSingleton()->getComponent<GUIComponent>();
		gui->alpha = 0.f;
		rs->updateGui(gui);
	}
}

void GameSystem::handleGameOver(artemis::Entity& e)
{
 	// sys_Movement->not_dead = 0.f;
	//sys_Movement->process();
	controllers->process();
	
	crs->not_dead = false;
	crs->process();
	col->process();
	ts->process();
}

void GameSystem::updateScripting()
{
	sys_Scripting->process(); // Possible multithread
}
