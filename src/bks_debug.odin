package game
import "core:fmt"
import "core:container/queue"
import "axiom"
display_player :: proc(p : Player)
{
    fmt.println("Player", p.name, "Position: ", p.pos, " Health: ", p.health)
}

display_deck :: proc(deck: ^BeeDeck)
{
    for i in 0..<36{
        if i > 0 && i % 6 == 0 do fmt.println()
        fmt.printf("%-12v ", queue.get(&deck.deck,i))
    }
    fmt.println()
}

display_temp_deck :: proc(deck: [dynamic]BeeAction)
{
    fmt.printfln("Temp Deck: ")
    for i in 0..<len(deck)
    {
        if i > 0 && i % 6 == 0 do fmt.println()
        fmt.printf("%-12v ", deck[i])
    }
    fmt.println()
}

display_bee :: proc (b : Bee)
{
    fmt.println("Bee ",b.name, ":  Position: ", b.pos)
}

display_level :: proc(battle : Battle)
{
    display_player(battle.player)
    for bee in battle.bees do display_bee(bee)

    // Create a simple character grid representation based on Tile and overlay entities (player + bees)
    chars : [GRID_WIDTH][GRID_HEIGHT]rune

    // Initialize chars from tiles
    for x in 0..<GRID_WIDTH do for y in 0..<GRID_HEIGHT
    {
        tile := grid_get(battle.grid, x, y)
        if .Blank in tile {
            chars[x][y] = '.'
        } else if .Wall in tile {
            chars[x][y] = '#'
        } else if .Weapon in tile {
            chars[x][y] = '!'
        } else if .Entity in tile {
            chars[x][y] = '.'
        } else {
            chars[x][y] = '?'
        }
    }

    // Overlay player rune if in bounds
    if path_in_bounds(battle.player.pos, battle.grid^) {
        chars[battle.player.pos[0]][battle.player.pos[1]] = battle.player.name
    }

    // Overlay bees (supporting the two global bees)
    // If more bees are added as globals, add them here similarly or change this function to accept a slice.
    for bee in battle.bees
    {
        if path_in_bounds(bee.pos, battle.grid^) {
            chars[bee.pos[0]][bee.pos[1]] = bee.name
        }
    }

    // Print header with coordinates (optional)
    fmt.println("Grid:")
    // Print rows: y from HEIGHT-1 down to 0 so increasing Y appears upward
    for y := GRID_HEIGHT - 1; y >= 0; y -= 1
    {
        for x in 0..<GRID_WIDTH
        {
            // Use %-3v for spacing so rune/emojis align reasonably
            fmt.printf("%-3v", chars[x][y])
        }
        fmt.println()
    }
}
