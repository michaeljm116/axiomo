* Implementing the odin polymorphism
* after this is done the character loop will probably change 
* right now its like:
	* check player status effects, check win/lose
	* do playerturn
	* check bee status effects, winlose
	* do bee turns
	* check status effects winlose
* and since its like multiple bee's theres added complexity
* now it'll be
	* for each character in queue:
		* Check conditions
		* Perform turn
		* Check conditions
		* if alive add back into queue
* the queue will be initialized at startup
* where should this queue reside in memory?
* just put it in the battle itself
* So how shall it go state wise?
	* End = Check Conditions pop and push queue
	* Start = Check Conditions
	* Continue = Perform Turn, which will check for end
	* Pause = nothing for now
	* question is... do you want a curr or just a queue.front?