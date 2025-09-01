
* 7 x 5 grid
* Horizontal
* 2 actions = 2 stamina bars
* It takes X seconds to fill 1 up
* Bee Moves every X seconds
* you move 1 grid per X Seconds
* or Run 2 grid per X Seconds
* You can find Weapons on the ground
* and pick them up and equip them
* When the Bee is threatened it can attack you
* if you walk slowly it wont be threatened
* if you run it will be


So first Grid data structure- adaptable for future level sizes
A start where you plop 4 things in the grid
* Player
* Bee
* 2  items
* items = random
So first there's the question of when to use a script and when to make a system...
A grid system is definitely needed
there is a grid system related to your collision... 
instead you should repurpose it so that first you have...
	a grid component with the position etc and name of entity
	then using debug every frame you can post info about the grid
