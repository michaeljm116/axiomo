#include "pch.h"
#include "game-app-system.h"
#include "Utility/window.h"
#include "Utility/Input.h"
//#include "Utility/xxhash.hpp"
#include "Rendering/rendermanagers.h"
#include "Rendering/renderSystem.h"
#include "ArtemisFrameWork/Artemis/Artemis.h"
#include "Utility/resourceManager.h"
#include "Utility/game-resource-manager.h"
#include "Scene/scene.h"
#include "Utility/transformSystem.h"
#include "Scene/Components/game-scene-component.h"
#include "Utility/script-component.h"
#include <Windows.h>
#include "dependency-validator.h"

using namespace Principia;
int main() {

	//VulkanValidator validator;
	//validator.install_vulkan();

	artemis::World world;
	artemis::SystemManager* sm = world.getSystemManager();
	artemis::TagManager* tm = world.getTagManager();
	world.setGameTick(0.016666666f);

	RenderSystem* renderSys = (RenderSystem*)sm->setSystem(new RenderSystem());
	//EngineUISystem* engineUISys = (EngineUISystem*)sm->setSystem(new EngineUISystem());
	TransformSystem* transformSys = (TransformSystem*)sm->setSystem(new TransformSystem());
	//AnimationSystem* animSys	  = (AnimationSystem*)sm->setSystem(new AnimationSystem());
	GameAppSystem* appSys = (GameAppSystem*)sm->setSystem(new GameAppSystem());

	artemis::EntityManager* em = world.getEntityManager();

	static artemis::Entity* singletonEntity = &em->create();
	static artemis::Entity* sceneEntity = &em->create();
	world.setSingleton(singletonEntity);
	world.setScene(sceneEntity);
	Script::world = &world;

	//WorldScript::get().SetWorld(world);
	std::string levels_folder = "1_Jungle";
	auto directory = "../Assets/Levels/" + levels_folder;
	Resources::get().LoadConfig("");
	Resources::get().LoadMaterials(directory + "/Config/Materials.xml");
	Resources::get().LoadDirectory(directory + "/Models/");
	Resources::get().LoadAnimations(directory + "/Animations/");
	GameResources::get().load_character_states(directory + "/Config/CharacterStates.xml");

	//Resources::get().LoadMaterials("../Assets/Levels/Level1/Materials.xml");
	//Resources::get().LoadDirectory("../Assets/Levels/Level1/Models/");
	//Resources::get().LoadAnimations("../Assets/Levels/Level1/Animations/");


	singletonEntity->addComponent(new ApplicationComponent());
	singletonEntity->addComponent(new GUIComponent(glm::vec2(0.0f, 0.f), glm::vec2(1.f, 1.f), glm::vec2(0.f, 0.f), glm::vec2(1.f, 1.f), 0, 1, false));
	singletonEntity->addComponent(new EditorComponent);
	//singletonEntity->addComponent(new GameComponent);
	singletonEntity->addComponent(new GameSceneComponent(0));
	singletonEntity->addComponent(new GlobalDataComponent(directory));
	singletonEntity->addComponent(new GameSettingsComponent(directory + "/Config/GameSettings.xml"));
	//singletonEntity->addComponent(new TitleComponent());
	GlobalController* controller = new GlobalController();
	for (int i = 0; i < NUM_BUTTONS; ++i) 
		controller->buttons[i].key = Resources::get().getConfig().controllerConfigs[0].buttons[i];
	for (int i = 0; i < 6; ++i)
		controller->axis_buttons[i].key = Resources::get().getConfig().controllerConfigs[0].axis[i];
	singletonEntity->addComponent(controller);
	//singletonEntity->addComponent(new GridComponent(16, 16));
	singletonEntity->refresh();
	appSys->change(*singletonEntity);

	////////////////////COMPONENTTYPETEST///////////////////////////////
	//auto bob = em->getComponents(*singletonEntity);
	//int count = bob.getCount();
	//for (int i = 0; i < count; ++i) {
	//	std::cout << typeid(bob.get(i)).name() << std::endl;
	//	artemis::ComponentType t;
	//	t = artemis::ComponentTypeManager::getTypeFor(typeid(bob.get(i)));
	//	t.getId();
	//}
	//auto ac = (ApplicationComponent*)singletonEntity->getComponent<ApplicationComponent>();


	try {
		Window::get().init();
		Input::get().init();
		transformSys->initialize();
		//physicsSys->addGroundForNow();
		renderSys->preInit();
		//renderSys->initialize();


		Scene::get().init(world);
		Scene::get().set_directory(directory + "/Scenes/");
		//engineUISys->findActiveCamera();
		//world.loopStart();
		//Scene::get().doStuff();
		//animSys->initialize();
		appSys->initialize();
		appSys->instantGameStart();
		//Scene::get().doStuff();
		world.loopStart();
		//world.loopStart();
		//Scene::get().buildBVH();
		appSys->initRenderer();

		static std::chrono::time_point<std::chrono::high_resolution_clock> start = std::chrono::high_resolution_clock::now();
		static std::chrono::time_point<std::chrono::high_resolution_clock> end = std::chrono::high_resolution_clock::now();
		static std::chrono::duration<float> duration;

#ifdef  NDEBUG
		ShowWindow(GetConsoleWindow(), SW_HIDE); 
#endif // ! NDEBUG

		while (!glfwWindowShouldClose(WINDOW.getWindow())) {
			//std::cout << "\n\n\n new frame \n\n\n";
			duration = end - start;
			world.loopStart();
			//Scene::get().buildBVH();
			float delta = duration.count();
			if (delta > 0 && delta < 1.f)
				world.setDelta(delta); 
			else
				world.setDelta(0.001f);
			glfwPollEvents();
			start = std::chrono::high_resolution_clock::now();
			pINPUT.update();

			appSys->process();

			end = std::chrono::high_resolution_clock::now();
		}
		world.setShutdown();
		vkDeviceWaitIdle(renderSys->getRenderer()->vkDevice.logicalDevice); //so it can destroy properly
	//	world.~World();
		//engineUISys->CleanUp();
		//renderSys->getRenderer()->cleanup();
		auto* computert = (ComputeRaytracer*)renderSys->getRenderer();
		appSys->imgui_renderer->destroyImGui();
		computert->CleanUp();
	}
	catch (const std::runtime_error& e) {
		std::cerr << e.what() << std::endl;
		return EXIT_FAILURE;
	}


	return EXIT_SUCCESS;
}

