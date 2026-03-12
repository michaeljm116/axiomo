# Animation
* Right now it only animates when a player moves
* there's no attack animations
* There's no general animation system like you had previously for how it works
* although you do hvae a general animation system
* So it does go to idle
* It does start walking
* but it does not loop the walk?
* but it does loop flying
* #BUG Gameover doesn't do what victory does
* There's n player attack
* so first... lets plot out animations....
# Goal
* When a character does an action, it smoothly transitions from the current animation it's at now to a new animation
* Then on the 
* honestly... it could just be a bad animation i dont see why tho

# Old System
* Character-Controller -> CharacterRotation -> Movement
	* Animation -> Animate 
* ### Movement
	* Get Direction -> forward and horizontal
	* Multiply it by movement speed
* ### Character Rotation
	* This has auto-rotation so keep that in mind
	* But basically it has hardcoded 8 directions
	* detect the 8 and set the rotation to that via quat slerp
		*  Based on Controller
	* set physics as well
* ### Character Controller
	* #### Added:
		* set InTrans to false (IMPORTANT for anims)
		* sets prevY to col->y
		* Loads_chartacter states... which just sets the anim times for all the things
	* #### Process:
		* Iterates anim times oh so attack systsm exists... 
		* Both have `transition` that are clearly defined as things
		* But yeah iterates time on both anim and movement
		* Then tyhere's a switch statement based on characterstate
		* and updates based on state
		* every tranistion starts by setting animationstate to default
		* starts the animation
		* oh nvm transitions dont exist in charactercontroller
			* it just sets the next state.type
		* okaay so EVERY ANIMATION MUST BE SET TO DEFAULT
		* every thing in the controller follows the pattern of:
			* set animation state to default
			* set animation, i think thats the key
			* attack still hase that transition pattern hmmm
			* but it seems like... you dont need to for default should figure out why
			* 