As a developer, I'd like a working prototype of the game in which I can go from room to room and battle to battle. The Battles will have all the main functionality of the game rules wit it's varied mechanics and all work in sync

## Mechanics left to do
* Player: Run
	* Lets you move 2 steps and if so alerts any bee's in sight
	* If bee's can't see you then you're fine
* Bee: Fly, Grounded
	* This mostly has to do with weapons, but affects animations
* Environment: Wall, Obstacle
	* Player cannot go through walls or obstacles
	* Bee's cannot go through walls but can obstacles
	* Obstacles can affect the line of sight of both 
* Player Line of Sight?
	* Maybe make it so walls also make anything behind the wall invisible?
* Weapon Mechanics:
	* Bug Spray, death in 2 turns.... 
## Analysis of Mechanics
* Run:
	* Additional movement option for run v walk
	* Easy thing would be... only 4directions and run = +2
		* Hard thing is what if you do Diagonals
		* This changes everything and might require a major restructure
		* Either mouse based picking or....
		* Yeah so you'd need to have a visible grid....
		* So you'd need a way for instead of like... you press WASD and it just goes auto
		* You Click move an a menu with grid blocks pop up and Pressing WASD highlights your options
		* Also if we do this, it would give it less of an action feel and more of a strategic feel
		* I want it to have more of an action feel tbh
		* I actually kinda like the current bug except yeah.... its buggy
		* But it like... gives you that freedom to adjust your mistakes on the fly
	* This is pretty complicated for now
	* Also keep in mind that the animation switches
* Bee: Fly, Grounded
	* Mechanics wise, it might already be in place...
	* Animations however...
		* This might also require a smaller bee
	* Is there any added mechanics you really need?
	* Is it just hooking everything up? or is it hooked up already?
* Environment: Wall
	* Can players walk through Walls?
	* Is a chest an obstacle?
	* Walk through chests?
	* Make them small enough? and hten player ndont collide?
* Weapons:
	* Bug Spray, Death in 2 turns... .how do es this work aka status effect
		* Also keep in mind that there's a double status effect check
		* actually there's currently 0, so should effects always be before their turn?
		* so lets think about a typical Burn mechanic
			* If burned, lose hp at start, if dead then die
			* So there's a problem of a bee that should be dead being selectable?
			* Not for the um... bug spray the rule is simply at start then check
			* Can't think of any end-time checks or reasons for that
			* but if so... then there would need to be a .Start and .End flag for each effect so decide on it now
			* I see no reason for end-turn effects
	* for death in 2 turns just have a .DieIn2Turns flag
	* on check status effect... if .DieIn2Turns then -= .DieIn2Turns += .DieIn1Turn end
	* If .DieIn1Turn then die 
	* This is not really scalable which is fine we don't expect any .DieIn40Turns
	* But to Make it scalable just do a .DieInXTurns then add an X int on the bee and subtract
	* tbh anything more than 3 turns would make the code too ugly
## Scope creep:
* Line of Sight
	* Might not actually be scope creep the main feeling you want is this desire to.... always be looking at the bee which is why you had that focus mechanic in the first place. knowing WHERE the bee is, is a very important aspect of the feeling you're trying to get at
* Obstacles
	* This is also very important for the feel you hope to have where its like... you're trying to position yourself for that hit but you have things in your way that's like... no big deal for the bee because of how small it is
* Expedition33 Dodge Mechanic 
	* which tbh so perfectly fits what I want in this game and tbh I originally intended for this to be a pure action game anyway and the only reason it went turn based in the first place is because it started as a card game and you hope to eventually make it pure action so maybe its best to do something like this

## Analysis of scope creep
* LOS: 
	* should be easy to add, just add a .Visible flag for now and code rules around that. Then just by default leave everything as .Visible in the beginning so you can in 1loc set everything as not .Visible at the start and when los is added you can have a function that checks visibility
* Obstacles... 
	* Might be more difficult, especially if you're able to move them that would require so much restructuring of code imo
	* if there's no moving of them... it'd be pretty simple. just add .Obstacle to grid 
	* Actually it would also complicate bee movement if you have something like... .Fly == Can move everythwere but .Grounded == can't do obstacles
	* Could make LOS complicated as well but you can also worry about that if LOS is worked on
	* SIMPLIFIED:
		* Player can't move on any .Wall or .Obstacle
		* Bee can't move on any .Wall
		* If Bee.pos == obs.pos then bee.flags += .OnObstacle
	* MEDIUM COMPLEXITY:
		* .Behind = proc([]obs, grid, player, bee) that if behind 1 obs then == .behind
		* Player cannot see .Grounded bee .Behind an .Obstacle
		* Bee that's .Grounded .Behind an .Obstacle cannot see player
	* HIGH COMPLEXITY:
		* If Player next to obstacle && IsAbleToPushInDirection
		* Allow push option
			* If pushed, any bee's on this obstacle is pushed as well and alerted
			* which means obstacles should track bees not just .obs on bee flag
			* Restructure grid and recalculate all .Behinds for all bees
			* Make sure player pos is updated 
			* Add new animation and sound
	* HIGHER COMPLEXITY:
		* If Player next to obstacle && IsAbleToPull || IsAbleToPickUp || IsAbleToThrow
* Action Dodge:
	* There's already a .Dodge flag
	* So when bee attack if .Dodge flag then...
	* Begin Attack Animation
		* If this can actually be complex cause its like
		* well just add a float of a perfect time
			* interp to that time then interp out that time
			* the closer to that time, the higher % chance to dodge
	* So at any time, the player can then try to press a button
		* when button is pressed player anim goes off?
		* but yeah then dice roll blah blah idk
		* idk for now but question is how to prepare for this?
	* I Think having a .Dodge flag is decent prep
	* Another good prep is there being animation interpolations based on given times
	* 