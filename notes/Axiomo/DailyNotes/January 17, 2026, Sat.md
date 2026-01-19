Plan:
* ~~Edit Mode: Press button to end battle~~
* ~~Fix Animation Bug~~
	* ~~Fixed: issue was no scene loaded after destruction~~
	* ~~This means a restart must include the scene its restarting to~~
	* ~~but destroy means... well idk... maybe have something thats like... idk there needs to be some kind of transition to overworld~~
	* ~~Ensure proper endings can work~~
* Make it so if battle ends you start overworld from the right
	* And you can't go back to that battle
	* This would require some good architecting
	* maybe default to go to overworld for now
	* wait so there needs to be some coordinates in place for overworlding
* Flying, Grounded Mechanics
* Add Status Effects

### Issue
* gpu memory is possibly leakable? its not in an arena
* but its managed in teh render system itself but yeah not safe
*


## Battle End flow:
* So when you end a battle....
* Question is.... what next? 
* 1. If you win, Go to... well now it expands to like gain exp etc... blah blah
	* and yeah ultimately you need to design that rpg system
* So for now:
	* Win = Go to Overworld
		* Cannot reenter battle
	* Lose = Go to Main Menu
		* Everything is reset

## Overworld STruct
* to get the next mechanic in you'll need an overworld struct that saves all the game data relavan to overworld and probably just in general player stats etc... for the rpg of it
* So for the purpose of the current objective you'd want a tuple of...
	* Battle Name
	* Pos:
		* x
		* y
	* Scale
		* x
		* y?
* I think to do this you  need a much better level setting program instead of just the levels.odin you currently have

## Levels
* Player Abilities should not be there should just be a file maybe
* Bees.... There should be bee types that are already configured
	* the positions should be set tho
* the grid and where the chest are shoudld be set too
* The level number shouldn't be s*