* Currently thinking about a stack based approach to character turns
* there's a constant question then of... how deep does the stack go and ultimately. you might just be doing the same thing
* idk how it'd work but ultimately there would be a stack that you pop and you perform that full turn until youlll well no other way
* you do the top of the stacks turn unti
* QUEUE not stack
* you do the full top of hte q's turn and when done you pop
* whenever a death occurs, they can no lonnger be added to the queue 
* but also all instances of them are removed from the queue
* sounds good but question is where si the queue decision engine?
* well actually.... when you pop your turn you insert yourself back into the queue. 
* and only do that if you're alive
* actually hmmm how would death work?
* there needs to be a way to decide on like who ot like... idk 
* but they can't just be pointers
* unless... thats exactly what htey are
* if they're pointers then...
	* ther'es a potentail problem of pointer missmatch
	* but doubt it
* if theyr'e poitners then it'd be na exact 64bit matchy match
* so at the start 


## Queue: 
* Start level = populate initial queue
* On turn end, push head to bottom of queue
* if you die, search through queue and remove yourself
	* not "you" though
* Queue Top = Run Character Turn
	* if character = player, run player turn
	* if character = bee, run bee turn
	