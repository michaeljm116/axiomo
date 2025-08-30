# Official
### Goal:

- Create a game world with a floor. The world will scroll from right to left endlessly.
- Add a player character that falls when no input is held, but rises when the input is held.
- Add obstacles that move from right to left. Feel free to make more than one type of obstacle.
    - Obstacles can be placed in the world using a script so the level can be truly endless.
    - Obstacles should either be deleted or recycled when they leave the screen.
- The score increases with distance. The goal is to beat your previous score, so the high score should be displayed alongside the current score.

### Stretch goal:

- Save the high score between play sessions.
- The jetpack is a machine gun! Add bullet objects that spew from your character when the input is held.
    - Particle effects are a fun way to add game juice. Mess around with some here, making explosions or sparks when things get destroyed!


OnStart:
* Player is on ground
	* If space is hit player accelration is up
	* else down
* Have a list of objects that go from left to right

## 10 Days
* Set up Scene with floor
* Set up main character
* Get physics working
* Move character up
* Make static obstacle
* PrintF obstacle collisions
* GameLoop!!! 
* 
*

Question: how will we do the endless world?
* 2 overlapping arenas
	* distance based arenas....
* 2 floors attached by the seam
	* attached to those arenas obvs
	* Then create dynamic objects based off that
* you can create the arenas in the gameplay.odin itself if ya want
* Make a json with 2 floors floor1 and 2
	* assign them to floor entitiies
	* each with their own respectivearenas
	* make floor 2 like 100 right of 1 maybe even programmatically
	* once floor 1 gets to -100 then mak
	* once A floor gets to 0 then the OTHER floor is that floors.x + 100 but also yadayada reset



### PHSHsycysics
Things you need to know abou thte phycis is..
1. should the ground physically move or be sttatic
2. this could make eveyrthing in the thing attached to the floor behat too but...
3. then the player would move along with the lfoor
4. unless you make it so there's a static floor that only the player interacts with
5. same with the top 
6. and then there's a second floor for the environment
7. that secnd floor has a texture blah blah and moves with the  level instead of it bien g just a blank texture and have it suber dense blah blah but yeah that keeps it in check with teh you know what
8. 