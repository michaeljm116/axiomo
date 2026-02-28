## Timed Turns
* Question is on the optionality of them
* also need to consider the stack
* #### Complexity analysis....
	* Right now... things are simple things are good
	* soooo at run player turn there would need to be some kind of... clock?
	* maybe one way to think of it is.... instead of from the bee-perspecctive its from the players
	* sooo you have a certain time untill you pop your turn
	* ....I don't like this, if its bee-based its better for multiple reasons
		* 1. you can have a timer icon over the bee
		* 2. multiple bee things
		* 3. it feels kind of unfair to the player unless clearly communicated
		* unless you have a timer icon over the players turn too
	* So lets think about bee-based
	* well if its bee-based... how do you do it? do you like push it to the top of the stack and what if there's a race?
	* also its a queue not stack
	* also what happens when its like... 4 player turns in a row?
	* I think ultimately its like... you'd generate a new copy of yourself and put that on the queue
	* i guess the first question is... can you only have 1 of you in a queue at a time? and if so how do you make that resilient?
* #### Grok
	* Make it fully time based also priority queues and stacks
	* don't fully understand how it works but could be interesting thought about full time base
* #### Current:
	* At the start of `run_battle.continue`
	* check `queue.front` 
		* if player run player turn if bee run bee turn
	* At the end of `run_battle`
		* curr = `pop_front`
		* push what you just popped back in queue
* #### Analysis:
	* If you were to do an interupt... the ves state of players turn would reset
	* state would reset
		* might be as easy as ves_clear_screens?
	* So it would be, reset plus pop a copy and run yo self instantly? except there would need to be some kind of copy flag because  curr would get pushed back at the end
	* question is how do you flag that you're a copy?
	* answer... add an instrurrup flag. just like now .Dead not in curr flags then do same with interrupt.... 
	* Next question: how to do the time decrease... 
		* add a timer on to bee... 
		* reset timer at .Start from run_battle
		* wait no... cuase then other bee's will also get reset 
		* So the timer should only be at the start of a player turn and reset at the end of the player turn
		* 