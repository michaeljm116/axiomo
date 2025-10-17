[[Excalidraw/Refactor|Refactor]]

eg.
``` go INPUT STATE
switch state{
	case enemy_select:	
		if(VisualEventSystem.EnemySelectScreen == JustTurnedOff)
			GameDataSyste.SetCurrEnemyTo(It)
			TransitionToPlayerActionSelect(state)
			
		
}
TransitionToEnemySelect(state)
{
	VisualEventSystem_ToggleENemySelectScreen(on)
	state = .enemy_select	
}
TransitionToPlayerActionSelect(state)
{
	VisualEventSystem_TogglePlayerActionSelect(on)
	state = .playerActionSselctt
}

ves_toggle_enemy_select_screen
{
ves.prev_screen = ves.screen
ves.curr_screen = {.enemy_select}
}

ves_update_screens
{
	if ves.prev_screen != ves.curr_screen
	if .enemy_select in ves.curr_screen{
		getscreen,
		alpha = 1.0
	}
	if .enemy_select in prev_screen{
		getscreen
		alpha = 0.0
	}
}


ves_update_all
{
	ves_update_screens
	ves_update_dice
	ves_update_animations
	ves_update_visualizations
}

ves_update_animation(character : anim, anim_state)
{
	switch state:
	case start:
		character.anim_state := .Start
		SetAnimation()
		state = update
	case update
		character.anim_state := End
		Animation += dt
		if over
			state = .End
	case end:
		character.anim_state := .End
		character.final_update
}

```

