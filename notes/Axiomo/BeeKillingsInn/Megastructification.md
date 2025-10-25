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
