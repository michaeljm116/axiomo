Grid with random weapons
2 grid 

## Structure:
* Title and Start Menu Main Menu Play Game Menu
* At Play Game There's a GameState and a Paused State
	* Paused Brings up the menus obvs
* In Game State
	* ~~You'll have Pokemon-Like Movement~~
	* Pressing WASD for .1 secs moves you in the square of that direction
	* It will be Semi-RealTime
	* 1 "Tick" will move you 1 square
	* All Enemies will operate per tick


* Crypt of the necrodancer?
* Turn Based?
* Just Try Real-Time


## Structure with engine:
* So you have Game, then the actual game logic which is diff from editor
* question is: what do?
* honestly i feel like game-scene-system should be in the game itself
* it doesn't make sense but it kinda makes se nse i mean you have:
	* The engine
	* The Game (that can be editable)
	* The Editor
	* The Game
* That second layer is mainly there because you want unique game things to be editable
* So the question is... do you want most of the game... like scripts for example, the game scene system for example.... the gameplay for example... pretty much anything else to be i the game or the editor?
* Another thing to keep in mind is even if this is all true... its also probable you didn't layer these correctly
	* Scene you want for both editable
	* if you want the editor to attach a script to a prefab then yeah.. it should be that way too
	* however it seems like you do all the things in the game-scene-system
		* currently
* IT's almost like... you want all components to be editable but the systems to be in game
	* components and scripts
	* but its like... components are worthless without the systems... so it should all be together
* oh yeah....
	* you want to be able to press PLAY in the editor lol
	* 