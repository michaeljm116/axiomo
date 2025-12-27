* ECS is useful for many thousands of objects your current game will have very little so theres no need for ecs right now.
* So should you just remove ecs and extern or just keep it?

So the main approach of the Megastruct would be that you'd keep all components as is and create a struct that auto has all things. 

Add component will automatically turn on a flag
wait so then... the megastruct will have
1. Components
2. flags
3. constant need to update

so then every time you update an entity you'd need to 
what are the problems you're actually having??!??! what if you're just using the ecs wrong... for some reason it seems to work fine without that added bee

Another issue is there's technically 2 megastructs there's like enginestruct and theres gamestruct or do all gamestructs inheritmegas?
also... even tho you may have a small ammount of entities.... you dont because each entity has like 20 other entities

i think you should just figure out hte issue you'r ehaving with the ecs you use now


what is the lifetime of your ecs?
if you plan on doing many adds/removes then its complicated but if its mostly just clearing a level off and on then its diff.

The lifetime is ultimately the entire scene. although unfortunately

### Memory Lifetimes:
* Data : Entire Program?
	* Technically its per-scene?
* BVH Data: per-frame
* Game Data: per-game
* Scene Data: per-scene... or is it?
	* yeah so scene data is per-scene. but because you might die often you dont want to constantly reload this after every death
	* but the complications are that it uses scene-data
* maybe this is the issue is you have scene data and game-data and they overlap
* What if, at the start of every scene you create the ecs world?
	* there is no remove_entity just pure idk
	* i think first thing is to fix the ecs to no longer remove any components
		* remove component is ONLY used for animate :)
* okay so the problem is there's like a scene resource data and the ecs data
* the scene resources should be allocated with a different allocator than the ecs (maybe)
* realistically you'd create many scenes and you'd probably delete
so its like... zone data, scene data, should scene data be in zone data? there's really no need to


So the ultimate question when it comes to lifetimes is...
* how do you want to structure your resources
* cause data isn't entire program its entire zone
* ... just leave it as that then
* so for a zone... everything that is currently global will be zonified
* but tbh it doesn't matter right now cause you dont plan on having zones
* so yeah there's now a question about data 
* well yeah so there's scene data and scene setup those should be separate
* load scene should load all scene data into the datamem
	* but something like a start_scene should start the scene and use that data's mem
* I think everything is fine, question is about scene data
* should there be a per yeah... there should
* sooo
Final