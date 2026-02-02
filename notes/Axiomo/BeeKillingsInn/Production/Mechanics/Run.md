As player I'd like a run mechanic that lets me go 2 blocks but doing so alerts a bee
### Rule:
* if player is able to go 2 blocks in a direction, let them
	* Is able: Not able if wall
	* Is able: Not able if obstacle
* If player runs and bee can see them, alert the bee
	* Can see: Player .IsVisible at start
	* Can see: Player .IsVisible at block 1
	* Can see: Player .IsVisible at block 2
* if a player can't move... maybe have a ERRERRR sound and shake
### Pseudocode:
``` go
if !is_player_turn return
if !player_selected return
if key_repeat(button.sprint) &&  key_press(button.direction){
	target, movable = check_move_options(player.pos, grid)
	if movable{
		alertbees(player.pos)
		alertbees(target[0])
		alertbees(target[1])
		
		move_player_to(target[1])
	}	
}
```

``` go
check_move_options :: proc(pos : vec2i, dir : 2b, grid : [][]vec2i) -> ([2]vec2i, bool)
{
	target : [2]vec2i{pos, pos}
	if dir.verticalbit
		if dir.up
			target[0].y = target[0].y + 1
			target[1].y = target[1].y + 2
	if !grid_check_in_bounds(target[0]) return (target, false)
	grid_check_in_bounds(target[1])
	grid_check_no_obstacles(target[0])
	grid_check_no_obstacles(target[1])
}
```

### Update movement:
* 1. Shift Pressed:
	* Display runable grids
	* Display walkable grids
* 2. *

* Hmmm... maybe you should always cache a list of runable and walkable grids every turn
* walkable : []Tile
* runable : []Tile
* this is a candidate for per-turn memory you talked about earlier

#### Possible issues
* how it interacts with other current and planned features:
	* line of sight
	* obstacles
	* Status Effects?
#### Possible ideas
* Have a bee that is alert by default
* Have a bee that is lofty and never looks at player
* Have a bee that can't see Player at block 1

# Implementing:
* The Api for the controller refactoring is done (for the most part)
* You revamped grid/battle to now just have a walkable, runnable flag in the grid
* so now to walk you just see if you can walk there or to run you see if you can run there
* seems simple, scalable and overall better
* There's a bunch of benefits to everything you've done overall
	* now if you want to ui the grid you have the tiles in place for that
	* there's a "bug" where you dont have blanks set up by default so instead of
		* .Blank in Tile its
		* Tile == {}
		* Idk if I want to do that or not....
			* Pros:
				* not having to constantly init the blanks
				* Is blank used for literally anything else?
					* blank could be a problem actually cause you can have
					* blank | Player in the same tile
					* having it as 0 means it is officially blank and nothings in
					* i wonder if there's an `is nil` ?
			* Cons:
				* Less expressive?
				* Technically Tile == null doesn't have to be a tile?
		* I think removing blank is best
		* DONE
	* Now blanks are fully blank
	* You can have a generic controller interfact that operates on whole game
	* eventually you can map right_axis to the mouse
		* i wonder if thats already in the cpp 
* Ultimately you'd want a game interface for this controller that lets you do things like map multiple keys to the same action
* aaaand now you're seriously considering that
* okay lets think about how much time you have and the pros and cons of that!
* Okay so now run is wroking and you got the game input layer. it actually gets the char over two blocks but obvs mistake in the speed of it which will be done in polish stage now.....
	* make it so it alerts both bees when it happens and youre done?
	* 

## Additional Game Input Layer
* Discription: As a programmer i'd like to have something that maps controller input to a game input so that way I can have selected actions that are mapped
	* It'd let me to something like... if  Pressed(.ActionButton) do action instead of if Pressed(.ActionU) WOW YOU ALREADY NAMED IT ACTION YOU DINGUS
	* This would also let me map multiple buttons like enter and space to the same action
		* but like when you're in the menu you can pick a diff one
		* infact you can have a GameController, MenuController etc....
		* but due to the type of game you're making they are probably gonna be the same
	* Risks:
		* Potential waste of time
		* less efficient
	* Mitigated:
		* 20 min timer
		* not really that much less efficient
	* Result:
		* worked but like 40 mins

## Next steps: 
* ~~Fix movement bugs for both run and walk~~
* AlertAllBee's need to include visiblity but visibility isn't happening yet soooo
	* i guess fix it using global state
	* move_player itsefl is kinda janky