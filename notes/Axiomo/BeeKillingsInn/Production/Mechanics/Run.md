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
