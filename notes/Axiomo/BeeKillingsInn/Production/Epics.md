## As a Player I'd like to start up the game and close it 
#### Discussion:
* Since this will be for a demo, I'd like the start up screen to remain on at all times
	* aka pressing esc doesn't shut down but just goes to the main screen
* So there should be a main screen that's just like... Start Game, Exit etc....
* No need for mouse controls just wasd 
* Keep in mind that the way your engine is structured you need some data to be loaded in the gpu at all times
	* but others can be revamped
* So yeah you'll need to get your gui system working
	* but also have some
	* ... no just show a simple texture with a PRESS SPACE TO PLAy kind of thing
	* maybe hold esc for 2 seconds to close as well


## As a Player, I'd like a beginning and end to the game
#### Discussion:
* So as said before, keep in mind the structure of your engine
* There should be something like a state machine that has a:
	1. Start
	2. Play
	3. Pause
	4. End
* Start loads a scene and all assets in a predefined order and sets off any rngs objects etc...
* Play runs the timer does all the gamey stuff
* Pause stops everything and plops a pause screen on the thing
* End Shuts down the scene and plops a main menu screen, probably some resuable code from pause

## As a Gamer in Play mode, I'd like to move around a grid
#### Discussion:
* As a first pass... just use a cube, please resist the temptation to use anything other than a cube
	* nvm a sphere might be better
	* nvm... you have a prefab system it literally doesn't matter 
		* unless you need to use that debug cube
	* also physics isn't that important in a grid, you can possibly remove the physics system?
		* Maybe let it stay if it's not bothersome and
		* oh gravity is definitely useful
		* but maybe let it stay just incause you wanna swatch
* So basically what you want is a system that smoothly transitions your character from one block to another
* WASD-Only
* 1 cube at a time
* you might have to make some kind of state machine that triggers some kind of overarching game structure that lets you know you've taken a single step
* Make sure there's bounds checking
* make sure there's some kind of structure that lets you know the [x,y] of the grid at all times
	* make sure you're always in the center of that square?

## As a Gamer in Play mode, I'd like an enemy to move around a grid

#### Discussion:
* So yeah it seems like an overarching game machine will be necessary
* For this epic you just want to make the a.i.... hmmm
* if you structure your player code correctly.... you can just reuse the same make_thing_go_to_square function 
* this will probably just use an RNG to go to some... ohhhh actually...
	* so the difference here si that the player can invalidly attempt to go to a square
	* while the bee MUST go to a valid square
	* so there will be bounds checking to see where the next valid square is
* so the main ask for this is a go to a valid square function
* but tbh you can probably do more... 
	* A* pathfinding shouldn't be too difficult in a 7x7 grid
* But then this begs the question of... should there be a previous story about how the grid operates?

## As a Gamer in Play Mode, I'd like a grid system
#### Discussion:
* So yeah there should be a grid system that starts off as being 7x7...
	* is there any reason it needs a limit? like does that NEEd TO BE hard coded? will it be that much of an effort to make it dynamic?
	* it should probs be dynamic from the start
* So at Start game: set the grid min-max
* The grid will be a 2x2 data structure that keeps track of all objects inside it
* There should be an update_grid(x,y) function that plops a thing on the grid
* The grid should be able to have walls
* idk I think that's it for now?

## As a Gamer in Play Mode, I'd like to be able to attack the bee
#### Discussion:
* is_in_range_of_bee::proc() -> bool
	* if true, allow attack to happen
	* if attack, kill bee
		* bee is deleted
		* overarching game system knows a bee has been elimitated
		* if all bee's in level is destroyed, victory == true
		* if victory, display you win screen and set state back to main menu or allow next level progression

## As a Gamer in Play Mode, I'd like to be attacked by the bee
#### Discussion:
* is_in_range_of_player::proc() -> bool
* is_alerted == true?
	* Attack player
		* overarching game system knows player is dead etc...
		* reset level since lost
		* display YOU DEAD BRO

## As a Designer, I'd like an overall rules engine
#### Discussion:
* Right now you're just looking at things as just like...
	* Player v bee and then just adding rules as you go
* But you need to first decide on all the rules from the get go 
	* and then plop those characters in as needed
	* So first decide on all the rules
	* then structure the code around all those rules
	* then place the charcters inside those rules
	* the rules engine is that overarching game system
	* [[Bee Ideas#Mechanics]]
	* The rules engine could be the entire game itself, in text form
	* So like...
	* Start game: Player is at 3,0, bee is at 3,6
	* Current Turn: player
	* Player is at 31, player has no weapon player picks up weapon player blah blah blah
* So yeah that's the game then thats the main game loop
* this should be done before any kind of visual anything
* so now just play the game and write doen the rules as you go
* 