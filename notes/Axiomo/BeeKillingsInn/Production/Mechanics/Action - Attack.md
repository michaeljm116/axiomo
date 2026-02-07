* Description : When player attacks bee...
	* if not facing bee, face bee
		* if bee not facing player, make bee face player?
		* Actually a discussion will be needed on how facing relates to alert
	* Camera switches to first-person mode
	* A Timer of some sort then starts
	* If player Presses button within timer zone, attack = success
		* else Miss 
	* Timer zone is based on weapon
* To do this, something will need to appear in the UI 
	* and that thing will need to dynamically update
* Camera work is lower priority for now

## UI 
* First design a meter in the UI which will have
	* Picture of weapon
	* Picture of Bee
	* Meter the Bee slides down
	* This is one spot where hot-reloading would be helpful
	* but yeah in the middle of the meter is a box that depending on the weapon will adjust the width
	* there might also be a bee-speed
	* line would be simplest
	* Zigzag would be dope
	* or maybe like the entire screen idk
* A single quick QTE with out much time to adjust
	* but the start up time can be a bit random as well
* ### QTE
	* LINE
	* BOX
	* BEE
	* HAND