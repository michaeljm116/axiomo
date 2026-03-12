* So yesterday you decided you wanted to have animations finally fixed and then you looked at you rprevious code to find out how you used to do it and got many pointers and then was like yoooo just redo the character controller!
* So now you're thinking you should just redo all that you did in the prev game minus the attacks
* But now that would mean adding more components etc related to the player which also asks the question of like.... since you destroy the ecs every room transition... should you remake it all again etc...
* i mean ultimately, overworld start should be creating the ecs already lets see
	* yeah it loads the scene and froku prefab
	* but
		* okay now you do app restart also possibly fixed the gameover bug
* So yeah none of those components are done lets check if theyre' in battle
* you got the move anim hash, times, attack times
	* thats it pretty minimal compared to c++
	* C++ has....
		* Cmp_Movement
		* Cmp_Character
		* Cmp_Rotation
			* ^ not actually used tho
	* honestly, none of these are needed to be ECS its just a single character
	*  