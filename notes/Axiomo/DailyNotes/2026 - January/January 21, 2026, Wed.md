* So right now you're trying to implement the more efficient battle system where step 1 is selecting 
* Problem is this codebase is littered with bees[bee_selection]
* but there also needs to be a distinction between bee_selections and player selection
* oops i mean bee selection and current_bee
	* maybe
	* 1 check to see if all bee selections are based on the concept of player selecting a bee
	* yeah it seems like it
	* so ultimately, you don't need a new variable, just the thing on top of the battlequeue
	* and can possibly use a variant
	* 
