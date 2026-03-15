# Animation bug
* Ultimately, the issue with transforms seem to be that you get trapped in a pingpong state between an almost ended transform and an end transform
* so a start is being set as an actual instaed of a pure start
* now technically this is what you want in a transition to make it smooth
* you want to set start for the animate component as the actual...
* but when its finlaized you want the true start to be started
* also... shouldn't the end technically be walk end and not idle end and like..
* yeah lets see
* oh yeah so thats potentailly what it does...
	* but actually possibly not
	* so the only reason you want the end pose is so you can return the non transitioners back to their original spot
	* even thoughh.... technically you'd want that end to be the default sqt
	* wait but you want to get both the start and end postes only to know like... what to return back, never in the end pose are you actually turning something back to its original
* ### Combined List:
	* At the start of the transition
	* Get a combined hashmap of the start and endposes
	* Set everything in the list to be...
		* start = where its currently at
		* end = the base transform
	* So what this should do is make everything go back to the original, periodT
	* now for every transitional pose.... if its already in the combined list.... then set the end to be the start of the transition
	* wait... the combined list in the c++ are actual tuples of the sqts....
	* ok odin does it too
		* okay back to c++
			* start = actual
			* end = original
			* but if trans t hen end = new start
		* trans :=
			* start = actual
			* end = trans.start
			* then it should go to
			* start = end
			* end = trans.end
		* what actually happens is...
			* end = actual
			* start = end?
	* odin?
		* The odin seems fine so it must be in add animation
* ### Add animation
	* what should happen:
		* since end = new start....
		* start = end
		* end = trans_end
	* soooo first of all... this is the thing where in c++ its ecs but odin its not
	* so question is... how do we set end to trans end on this?
	* it does it in the transition
	* it sets errthang in the transition
	* wait...
	* endpose = confirmed to be the actual endpose eg. walk_end
	* 

# Friday
* Today and tomorrow you're gonna speed run through a bunch of different things such as:
* Text Rendering
* %% Memory %%
* %% Animations %%
* Sounds
* %% Overworld %%
* %% Win/Lose Finishing %%
* Dealing with any notable bugs
* %% Tonight you finish persistence %% 

Question with text rendering is....
* Do you even want it?
* Yes it would make things super helpful debugigng wise
* also ui wise

# Text rendering approach:
* so there's a texture of fonts right
* and then you'd want to make a ui that samples the texture multiple times
* then creates a gui component that has the combination of all those samples into a single texture
* is it something like that? idk lets ask opencode
