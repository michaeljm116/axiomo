asdf
So there's an issue of views where....
you need to first add components and stuff before you start the views
but you wanted the views to be after the components 

number one thing to keep in mind in this ecs....
Tables First then views
and tables are created by adding a component....
unless you just go ahead and make it so if during view creation if the table doesn't exist... make it

Okay so what you need is upon world creation to pre-create every important table and only in unexpected results should unexpected tables be made

same for views tbh
another thing to consider is if this is engine only or also game...
