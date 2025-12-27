 Okay so here's the um... thang right here lemme spit...
 * So lets say you place focus o
 * ... real talk... this is why ecs is awsome
	 * you can just put a focus component on a bee and create a focus system
 * so the issue with your locals vs globals is...
	 * the locals of all parents are basically the globals
	 * so when you want one thing above another hting
	 * you need to consider if its local or global blah blah
	 * like if I want my hand above another things hand..
	 * nvm i cant even...
		 * its like... you'd want that local parent to be ahhhhhhh...
		 *
## Dice Rolls
* ```go odin
  dice_rolls :: proc() -> i8 {
   d1 := rand.int31() % 6 + 1
   d2 := rand.int31() % 6 + 1
   fmt.printf("Dice rolls: %d + %d = %d\n", d1, d2, d1 + d2)
   return i8(d1 + d2)
}
```

* So the first thing you'll want to do is return 2 i8s
* then you'll want to set up an animation
	* which means there's going to be a (possibly new) state
	* that is time based on animation and at the end of the anim you roll the dice
	* start with random number and the end will be rand number + rand number
	* then go like... maybe 15 rolls until it lands on that random number
	* now that i think about it... it doesn't have to be in order, dice are never in order
	* so just every frame show a new random number and then just stop at anim time
* so consider.... the gui component

```go
Cmp_Gui :: struct {
    min: vec2f,
    extents: vec2f,
    align_min: vec2f,
    align_ext: vec2f,
    layer: i32,
    id: string, //Texture
    ref: i32, // Gpu reference
    alpha: f32,
    update: bool,
}
```

* So i think it's just the align min that needs to shift
* you technically only need 1 dice
* but you can design the 6 dice to get a feel for where the align min should be
* but for the function just adjust the alignmin

* 4 seconds i think is the time of awkwardness... so 4 secs for the thing
every... .25 secs threshold
* 2 of these

```go
Dice :: struct {
	num : i8,
	curr_time : f32,
	max_time : f32,
	interval : f32,
	 curr_interval : f32,
}
dice_rolls :: proc(dt : f32, )
```



Okay so the way this should work is... everything should  happen under an Action-Display Paradigm
* aka mvc? 
* with some waits?
So lets think about the fack that you are running everything at 60fps
You have an event
so technically theers like 3 things
* poll
* update
* render
* update
but is that last update really needed?
* so like... maybe
* not necessarily, *