* It seems like when you delete an entity... it just... keeps some kind of entity tracker at that entity pos and it does not set that entity back to 0... 
	* but that also makes sense because you need to like... do stuff
	
	
# New ECS
* so 1 the views are pointers
* must init always
* also keep in mind the memory that they use, specifically the bvh like make sure the bvh alloc is different from the ecs usage of the bvh
* *