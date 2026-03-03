* What is the ACTUAL problem  you're trying to solve and what is currently the issue?
* i mean yeah the ves is going against your philosophy on what it should do but.... is it working?
* do you plan on expanding things beyond what you're doing?
* is it currently causing issues other than confusion?
* once dodge is added... will you ever go back to this issue?!?
* another issue is not having stack menus adn instead doing manual enums for everything


## Screen Stack:
* currently ves_update_screen constantly checks for a change from curr to prev screen it works as a simple switch statement right now but a more elegant approach is for it to be a stack
	* and with this, apparently have an on_enter on_exit for each screen
* so it just undoes the prev screen and does the curr screen...
* what if
	1. No ves_upduate_screen
	2. instead of a manual g.ves.curr_screen = vesscreen.Thing
	3. do ves_screen_push(vesscreen.thing)
		1. ves_screen_push checks whats on already and calls on_exit(thing)
		2. on_exit removes all the elements
		3. pushes on the stack
		4. and does on_enter(thing)
		5. both on_enter and on_exit are switch statements kinda like what you see here
	4. this code is like nearly identical tbh what is the benefit?

# Animation Queue:
* so for player movement its...
	1. if you're in the movement state
		1. wait for a players movement
		2. if so then add aim_flag
		3. and do added {.animate}
	2. then on added {.animate}
		1. if you're a player start the animation
		2. update the animations and finish animations
	3. then on movement state you wait for a finish flag