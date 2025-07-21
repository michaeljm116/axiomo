#include "../pch.h"
#include "game-app-system.h"
#include "../Rendering/renderSystem.h"

GameAppSystem::GameAppSystem()
{
	addComponentType<ApplicationComponent>();
	addComponentType<GlobalController>();
}

GameAppSystem::~GameAppSystem()
{
}

void GameAppSystem::initialize()
{
	//Initialize the window
	glfwSetWindowUserPointer(WINDOW.getWindow(), this);
	glfwSetWindowSizeCallback(WINDOW.getWindow(), GameAppSystem::onWindowResized);

	//Initialize the mappers
	appMapper.init(*world);
	controlMapper.init(*world);

	//Get the managers
	artemis::SystemManager* sm = world->getSystemManager();

	//First get references to the already started systems
	rs = (RenderSystem*)sm->getSystem<RenderSystem>();
	bvh = (BvhSystem*)sm->getSystem<BvhSystem>();
	//bvh->setCamera(findCamera());

	//next create references to new systems
	game = (GameSystem*)sm->setSystem(new GameSystem(true));
	//gss = (GameSceneSystem*)sm->setSystem(new GameSceneSystem());

	prefabSys = (PrefabSystem*)sm->setSystem(new PrefabSystem()); // are these sys necessary???
	prefabSys->initialize();
	poseSys = (PoseSystem*)sm->setSystem(new PoseSystem());

	//selectable_gui_sys = (Sys_Selectable_GUI*)sm->setSystem(new Sys_Selectable_GUI());
	//selectable_gui_sys->initialize();

	//next initialize the old systems
	rs->getRenderer()->UpdateDeviceInfo();

	//Next initialize the new systems;
	game->initialize();
	//gss->initialize();
	poseSys->initialize();
	//col system initialize idk why colsys is in scene or whereever but ima do dis

	sceneChangeSys = (SceneChangeSystem*)sm->setSystem(new SceneChangeSystem());
	sceneChangeSys->initialize();

	//Menus
	//flappy_menu = (FlappyMenuSystem*)sm->setSystem(new FlappyMenuSystem());
	//flappy_menu->initialize();
	//world->getSingleton()->addComponent(new FlappyBirdMenuComponent());

	debugger = (Sys_Debug*)sm->setSystem(new Sys_Debug());
	debugger->initialize();

	prev_time = std::chrono::high_resolution_clock::now().time_since_epoch().count() / 1000000;
	curr_time = prev_time;
	lag = 0;
}
void GameAppSystem::initRenderer()
{
	updateBVH();
	rs->initialize();
	rs->getRenderer()->UpdateDeviceInfo();

	imgui_renderer = new ImGuiRenderer(rs->getRenderer());
	imgui_renderer->initImGui();
	debugger->setImGui(imgui_renderer);
	uint32_t index = 0;
	rs->startFrame(index);
	auto* submit = &rs->getRenderer()->GetSubmitInfo();
	imgui_renderer->start_draw(submit, index);
	imgui_renderer->end_draw(submit, index);
}
void GameAppSystem::processEntity(artemis::Entity & e)
{
	ApplicationComponent* ac = appMapper.get(e);
	GlobalController* gc = controlMapper.get(e);

	//selectable_gui_sys->update();
	//flappy_menu->process();
	//Handle input
	for (int i = 6; i < 11; ++i) {
		int action = pINPUT.keys[gc->buttons[i].key];
		gc->buttons[i].action = action;
		if (action == GLFW_PRESS) {
			switch (i) {
			case 6:
				//toggleEditor(ac->state);
				break;
			case 7:
				WINDOW.toggleMaximized();
				break;
			case 8:
				toggleRender();
				break;
			case 9:
				glfwSetWindowShouldClose(WINDOW.getWindow(), 1);
				break;
			case 10:
				//world->getSingleton()->addComponent(new GameSceneComponent(1));
				break;
			}
		}
	}
	curr_time = std::chrono::high_resolution_clock::now().time_since_epoch().count();
	lag += curr_time - prev_time;
	prev_time = curr_time;
	
	static uint32_t ii;
	rs->endFrame(ii);
	static const float  fps_60 = 16666666;
	static const float  fps_120 = 8333333;
	if (lag > fps_60) {
		lag = 0;
		switch (ac->state) {
		case AppState::Startup:
			break;
		case AppState::Editor:
			break;
		case AppState::Play:
			game->updateScripting();
			//sceneChangeSys->process();
			game->process();
			break;
		default:
			break;
		}
		updateBVH();
	}
	rs->process();
	rs->startFrame(ii);
	auto* submit = &rs->getRenderer()->GetSubmitInfo();
	imgui_renderer->start_draw(submit, ii);
	debugger->process();
	imgui_renderer->end_draw(submit, ii);
	return;
}

void GameAppSystem::instantGameStart()
{
	//WINDOW.toggleMaximized();
	//WINDOW.toggleMaximized();
	RenderSystem* rs = (RenderSystem*)world->getSystemManager()->getSystem<RenderSystem>();
	//rs->TogglePlayMode(true);
	//rs->removeUI();
	//game->findGoals();

	auto& se = *world->getSingleton();
	AppState& as = appMapper.get(se)->state;// = AppState::Editor;
	as = AppState::Play;

	se.addComponent(new TitleComponent());
	se.addComponent(new GameComponent());
	//toggleEditor(as);
}

void GameAppSystem::toggleEditor(AppState& s)
{
	//toggles the editor by passing or removing the editor component 
	//Problem: this is too couplely and syou should be able to take off editor w/o gaming
	//artemis::Entity* singleton = world->getSingleton();
	switch (s)
	{
	case AppState::Play:
		//singleton->removeComponent<GameComponent>();
		//singleton->addComponent(new EditorComponent());
		s = AppState::Editor;
		rs->TogglePlayMode(false);
		break;
	case AppState::Editor:
		//singleton->removeComponent<EditorComponent>();
		world->getSingleton()->addComponent(new GameComponent());
		rs->TogglePlayMode(true);
		game->change(*world->getSingleton());
		s = AppState::Play;
		break;
	default:
		break;
	}
}
void GameAppSystem::toggleAppState(AppState& s) {
	artemis::Entity* singleton = world->getSingleton();
	switch (s)
	{
	case AppState::TitleScreen:{
		singleton->removeComponent<TitleComponent>();
		singleton->addComponent(new MenuComponent());
		s = AppState::MainMenu;
		break;}
	case AppState::MainMenu:{
		singleton->removeComponent<MenuComponent>();
		singleton->addComponent(new GameComponent());
		s = AppState::Play;
		break;}
	default:
		break;
	}
}

void GameAppSystem::togglePause(AppState& s)
{
	artemis::Entity* singleton = world->getSingleton();
	switch (s)
	{
	case AppState::Play:
		singleton->removeComponent<GameComponent>();
		singleton->addComponent(new PauseComponent());
		s = AppState::Paused;
		break;
	case AppState::Paused:
		singleton->removeComponent<PauseComponent>();
		singleton->addComponent(new GameComponent());
		s = AppState::Play;
		break;
	default:
		break;
	}

}

void GameAppSystem::toggleRender()
{
	//rs->editor = !rs->editor;
	//rs->cleanupSwapChain();
}

void GameAppSystem::updateBVH()
{
	//if (bvh_3rd_party) {
	//	bvh->build_madman();
	//	rs->updateBVH(&bvh->bvh_, bvh->prims);
	//}
	//else {
		//bvh->build();
		//rs->updateBVH(bvh->prims, bvh->root, bvh->totalNodes);
		bvh->build();
		rs->getComputeRaytracer()->UpdateBVH(bvh->get_ordered_prims(), bvh->get_original_prims(), bvh->get_root(), bvh->get_num_nodes());
	//}
}

auto GameAppSystem::findCamera() -> artemis::Entity*
{
	auto* em = world->getEntityManager();
	int count = em->getEntityCount();
	for (int i = 0; i < count; ++i) {
		auto* node = (CameraComponent*)em->getEntity(i).getComponent<CameraComponent>();
		if (node != nullptr) {
			return &em->getEntity(i);
		}
	}
	std::cout << "\n ERROR: COULD NOT FIND CAMERA \n";
	return nullptr;
}
