#pragma once
/* Input System Copyright (C) by Mike Murrell

*/
#include "../Utility/Input.h"
#include "Components/controllerComponent.hpp"

using namespace Principia;
//class ApplicationSystem;

class ControllerSystem : public artemis::EntityProcessingSystem {
private:
	artemis::ComponentMapper<ControllerComponent> controllerMapper = {};
public:
	ControllerSystem();

	void initialize();
	void begin();
	void processEntity(artemis::Entity & e);
	void handle_gamepad(ControllerComponent* gamepad);
	void handle_keyboard(ControllerComponent* keyboard);
	void handle_button(Button* button);
	void handle_gamepad_state(Button& button, const unsigned char& state);
};

