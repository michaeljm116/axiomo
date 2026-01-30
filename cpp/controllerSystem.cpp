#include "../sam-pch.h"
#include "controllerSystem.h"
#include "../Application/Components/applicationComponents.h"

#include "Utility/nodeComponent.hpp"
#include "glm/gtc/epsilon.hpp"
#include "cast.h"

ControllerSystem::ControllerSystem() { 
	addComponentType<ControllerComponent>(); 
}

void ControllerSystem::initialize()
{
	controllerMapper.init(*world);
}

void ControllerSystem::begin() {

}

void ControllerSystem::processEntity(artemis::Entity & e)
{
	ControllerComponent* controller = controllerMapper.get(e);

	//auto* nc = (NodeComponent*)e.getComponent<NodeComponent>();
	

	if (controller->type == InputType::Gamepad)
		handle_gamepad(controller);
	else
		handle_keyboard(controller);
}
static inline float handle_epsilon(float val) {
	return val * glm::ceil((abs(val) - 0.05f));
}

void ControllerSystem::handle_gamepad(ControllerComponent* gamepad)
{
	GLFWgamepadstate state;
	if (glfwGetGamepadState(0, &state)) {
		for (int i = 0; i < 15; ++i) {
			handle_gamepad_state(gamepad->buttons[i], state.buttons[i]);
		}
		gamepad->left_axis.x = handle_epsilon(state.axes[0]);
		gamepad->left_axis.y = -handle_epsilon(state.axes[1]);
		gamepad->right_axis.x = handle_epsilon(state.axes[2]);
		gamepad->right_axis.y = -handle_epsilon(state.axes[3]);
		gamepad->left_axis.z = handle_epsilon(state.axes[4]);
		gamepad->right_axis.z = handle_epsilon(state.axes[5]);


		gamepad->moving_left_axis = !((gamepad->left_axis.x * gamepad->left_axis.x + gamepad->left_axis.y * gamepad->left_axis.y) == 0);
		gamepad->moving_right_axis = !((gamepad->right_axis.x * gamepad->right_axis.x + gamepad->right_axis.y * gamepad->right_axis.y)== 0);

	}
}

// Unnecessary useless optimization that's probably not even optimal all to avoid using if statements\\
// Makes it so that if you get a 2 or a 1 it will just be a 1
static inline int Oneify(int a) {
	return ((a + 1) & 2) >> 1;
}
static inline float Oneify_f(int a) {
	return static_cast<float>(((int)(a + 1) & 2) >> 1);
}
void ControllerSystem::handle_keyboard(ControllerComponent* keyboard)
{
	glm::vec3 tempAxis;
	for (int i = 0; i < NUM_BUTTONS; ++i) {
		handle_button(&keyboard->buttons[i]);
	}
	for (int i = 0; i < 6; ++i) {
		handle_button(&keyboard->axis_buttons[i]);
	}
	//add 1, and 2 shift right
	tempAxis.x = to_flt(-Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Left].key]) + Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Right].key]));
	tempAxis.y = to_flt( - Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Down].key]) + Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Up].key]));
	tempAxis.z = to_flt( - Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Backward].key]) + Oneify(pINPUT.keys[keyboard->axis_buttons[Keyboard_Forward].key]));

	keyboard->left_axis = tempAxis;
	keyboard->moving_left_axis = !((tempAxis.x * tempAxis.x + tempAxis.y * tempAxis.y) == 0);
}

void ControllerSystem::handle_button(Button* button)
{
	//Query the INPUT singleton to see if the key has been pressed
	int action = pINPUT.keys[button->key];

	//If it has been pressed/continued update it
	button->action += action;
	if (action >= GLFW_PRESS) {
		//Check if it's in continue or if its an initial press
		if (button->time == 0)
			button->action = GLFW_PRESS;
		button->time += pINPUT.deltaTime;
	}
	//If it has been released 
	else if (action == GLFW_RELEASE) {
		//Check if it's been initially released or just blank
		if (button->time > 0.f)
			button->action = -1;
		else
			button->action = 0;
		button->time = 0.f;
	}
}

void ControllerSystem::handle_gamepad_state(Button& button, const unsigned char& state)
{
	button.action += state;
	if (state >= GLFW_PRESS) {
		if (button.time == 0)
			button.action = GLFW_PRESS;
		button.time += pINPUT.deltaTime;
	}
	else if (state == GLFW_RELEASE) {
		if (button.time > 0.f)
			button.action = -1;
		else
			button.action = 0;
		button.time = 0.f;
	}
}
