# Village Emerald Run — journal

- Host: Resident Evil 4 remake, RE Engine, slug resident-evil-4.
- Route: REFramework Lua autorun. Melty installs REFramework v1.5.9.1 by itself. Not patching re4.exe.
- Sonic Frontiers: related idea only (custom-sonic-frontiers). Not in Melty's catalog. No files read or shipped.
- Anti-cheat: Melty did not flag either game. Solo offline story use.
- Game folder on the player's PC: c:\\program files (x86)\\steam\\steamapps\\common\\RESIDENT EVIL 4  BIOHAZARD RE4
- This environment: that path is not mounted. No in-game launch, screenshot, or clip yet.
- Player API used (from praydog scripts/utility/RE4.lua): CharacterManager:getPlayerContextRef, get_BodyGameObject, Transform get_Position / get_AxisZ / set_Position.
- Boost does not consume input and does not touch weapon components, so aim and fire stay with the game.
- Course is planted at runtime (F6) because village coordinates were not verified in a running game.
- Music: best-effort pitch-up on the current chapter track at the gate. Overlay reports if the hook is missing.
