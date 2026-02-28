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
	* 