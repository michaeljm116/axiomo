#pragma once
#include "../pch.h"

/*
NINTENDO SWITCH CONTROLLER :
directional buttons = 16 - 19
b / v = 1
a / > = 3
y / < = 0
x / ^ = 2

+ / -= 8

13 = HOME BUTTON
*/

/*
0-3 = MAIN BUTTONS
4 = PAUSE
5 RIGHT SHOULDER
6 = RIGHT BACK
7 = LEFT SHOLDER
8 = LEFT BACK
9 = home button = exit
and theres an axis of course
*/
	enum class InputType
	{
		Keyboard,
		Gamepad,
		JoyStick,
		AI
	};
	struct Button {
		int key;
		int action;
		double time;

		Button& operator= (Button& b) {
			key = b.key;
			action = b.action;
			time = b.time;

			return *this;
		}
	};
//#define NUM_BUTTONS 16
	constexpr int NUM_BUTTONS = 16;
#define NUM_GLOBAL_BUTTONS 16
#define NUM_ACTIVE_BUTTONS = 4
	///ControllerComponent, NOTE: first 6 buttons are for the axis
	/// goes in order of +x +y +z -x -y -z
	struct ControllerComponent : public artemis::Component {

		//glm::vec3 direction;
		//int32_t index;
		//float button[12]; //time held
		Button buttons[NUM_BUTTONS] = {};
		Button axis_buttons[6] = {};
		glm::vec3 left_axis = glm::vec3();
		bool moving_left_axis = false;
		glm::vec3 right_axis = glm::vec3();
		bool moving_right_axis = false;
		int index = 0;
		InputType type;
		ControllerComponent(int id) : index(id) {
			if (id == 1) type = InputType::Keyboard;
			else if (id == 3) type = InputType::Gamepad;
		};
		ControllerComponent(ControllerComponent* cc) {
			left_axis = cc->left_axis;
			right_axis = cc->right_axis;
			index = cc->index;
			type = cc->type;
			for (int i = 0; i < NUM_BUTTONS; ++i) {
				buttons[i] = cc->buttons[i];
			}
			for (int i = 0; i < 6; ++i) {
				axis_buttons[i] = cc->axis_buttons[i];
			}
		}

		/*so you toss in a 21 and you turn it into a buttonything
		also have index so you can save
		*/
	};

	struct GlobalController : public artemis::Component {
		Button buttons[NUM_GLOBAL_BUTTONS] = {};
		Button axis_buttons[6] = {};
		glm::vec3 axis = glm::vec3();

		GlobalController() {};
	};

	enum EditorButton {
		EditorButton_LeftBracket = 0,
		EditorButton_RightBracket,
		EditorButton_F11,
		EditorButton_Escape,
		EditorButton_Backslash
	};

	enum ControllerButton
	{
		Keyboard_Right = 0,
		Keyboard_Up,
		Keyboard_Left,
		Keyboard_Down,
		Keyboard_Forward,
		Keyboard_Backward
	};
