### Game
* Turn based Combat
* All Decisions can only be done on turns
* Game Ends when a side has fully died
* Loop goes: 
	* Check For Player Status Effect
	* Check For Win/Lose Condition
	* Player Turn
	* Check For Win/Lose Condition
	* Check For Bee Status Effect
	* Check For Win/Lose Condition
	* Bee's Turn 
	* Check For Win/Lose Condition
### Grid
* The level will be a grid, can't go out of bounds
* Grid is 4 directions, no diagonals
* A Diagonal is NOT considered 1 away
* The grid will have different kinds of tiles
	* Blank
	* Entity
	* Wall
	* Item
* Entities can move on any kind of tile except wall
* Landing on an Item does automatically picks up what's inside
### Player
* Defaults to 1 Action Per turn
* 3 Categories of Actions
	1. Attack
	2. Prepare
	3. Move
* Can only Attack bee's in range
* Range is decided on Weapon Type
* Damage to bee is decided on weapon type
* Can only have 1 weapon equipped at a time
* Defaults to move one block per turn
* Can move 2 blocks in a turn but instantly alerts all bees
### Bee
* Defaults to 1 Action Per Turn
* 2 Categories of Actions
	* 1. Attack
	* 2. Move
* Can only Attack 0 - 1 away from player
* Can only Attack if the bee is alerted
* If Bee Overlaps player is automatically alerted
* 2 Categories of states
	* Flying
	* Crawling
* These states mostly affect how player weapons operate
* Can have many categories of behaviors
* Bee's will have a deck of card potential actions to choose from
* Their behaviors affect how they choose the cards
* A Default bee will attack based off which card they draw
* Other bee's will be able to draw 2 or more cards and choose one based off their behavior
* Ex. Aggressive bee will draw 2 cards and choose the more aggressive one

### Weapons

### Beehaviors