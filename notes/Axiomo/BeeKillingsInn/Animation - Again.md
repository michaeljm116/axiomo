1. Add a bfg comoponent
2. flatten it
3. add it to the entityt
4. add an animation component which has...
	1. Number of poses
	2. Name of Pose
	3. Name of Start Animation
	4. Name of End Animation
	5. Animation flags which tells you
		1. id po? id of the pose im guessing but ultimately useless tis always 0
		2. loop - if true then the animation loops
		3. force start - if true then it forces the character to start with no transition from prev 
		4. force end - forces animation to end with no transitiotn out
5. So now that the animation has been added, go to add animation proc which... basically does everything
	1. Gets the Endpose from resources
	2. if there's only 1 for num_poses, create an anim comoponent that...
		1. sets the end to that end pose
		2. sets the start to whatever youo're transform is right now
		3. adds that component to the... entity??? idk why its going the bfg->nodes[p.first] rout
	3. else 
		1. ...why is num_poses an int instead of a bool? regardless lets say theres 2 poses...
		2. This will create both a start and end pose
		3. beofre the if you get already got the end pose so now just get the start pose from resrouces
		4. OOPS!!! NOTE!!! THESE ARE ALL LOOPS A POSE IS A COLLECTION OF TRANS
			1. So for the start poses... just straight up insert all the starts same as how you did for endpose blah blah 
			2. keep in mind that you turn the startset flag to true
			3. 
6. The processing of animations are ONLY for transitions, otherwise there is no real processing

### sooo
* one thing to keep in mind is this is like a full blown ecs system
* you add a component, process it and then remove it
* so the first question is... do you wanna?
* another option would be that each entity has its own animate component that's either active or inactive
* 