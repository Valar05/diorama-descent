# Concept

## Summary

`Diorama Descent` is a landscape-first 3D sprite-action game. The player starts on a readable grid, then transitions into close-range combat that uses the slash language and sprite-facing style from Diorama of Descension.

## Intended Flow

1. Player enters a map with visible route and enemy telegraphs.
2. Movement is grid-based, using the left-side joystick.
3. Enemies preview their next move.
4. Contact causes a clash and resolves free hits based on approach direction.
5. Combat camera snaps behind the player.
6. Swipes drive directional slashes.
7. Dodging is handled by the left stick and resets automatically after the dodge window.

## Input Rules

- One tile per second while movement is held.
- Reject diagonals unless one axis is clearly dominant.
- Swipe direction should map to slash direction.
- Dodge is separate from attack.
- You cannot attack while still locked in the dodge state.

## Combat Rules

- If the player runs into the enemy tile, the enemy gets a free hit.
- If the player enters from side or rear contact, the player gets a free hit.
- Goblins should keep their attack tells visible in the close combat frame.
- A successful dodge should make the goblin miss and reset its pressure loop.

## Visual Rules

- The layout should mimic the original diorama composition.
- Use sprites in 3D space instead of switching to fully modeled characters.
- Keep the scene in landscape.
- The background should preserve the Diorama look rather than moving to a generic flat prototype view.
