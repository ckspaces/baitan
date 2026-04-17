# Collaboration Change Log

## 2026-04-16

### Author
- Codex

### Changes
- File: `COLLABORATION.md`
- Purpose: create a shared collaboration guide for the project
- Details: documented project structure, collaboration rules, log template, and current phase goals
- Risk: no runtime risk
- Validation: file created for ongoing shared use

- File: `CHANGELOG_COLLAB.md`
- Purpose: create a persistent place to record all future changes
- Details: initialized the collaboration change log and recorded the documentation bootstrap step
- Risk: no runtime risk
- Validation: future edits will append here after each code change

- File: `scripts/core/StallSystem.lua`
- Purpose: fix promotion cooldown progression so promotions can be reused after cooldown
- Details: updated `tickPromotion` so cooldown decreases even when no promotion is active, and the first cooldown day is not consumed on the same tick that a promotion ends
- Risk: promotion availability timing changes by one settlement tick after promotion end
- Validation: logic reviewed against activation checks and cooldown UI display

- File: `scripts/scenes/CharacterRenderer.lua`
- Purpose: improve weather realism for the main character
- Details: added snow-day winter hat and padded outerwear visuals, and started adding rainy-day umbrella rendering for the player character
- Risk: weather render code still needs a cleanup pass because some string literals did not replace cleanly in the current Windows patch flow
- Validation: diff reviewed; follow-up cleanup still required before considering this fully finished

- File: `scripts/scenes/StallScene.lua`
- Purpose: improve weather realism for background pedestrians
- Details: stored weather on spawned pedestrians and added snow-day outerwear and winter hat layers to street characters
- Risk: weather-specific render state was added incrementally and still needs one cleanup pass for consistency with the player renderer
- Validation: diff reviewed; visual feature work landed, but final cleanup is still pending

## 2026-04-17

### Author
- Codex

### Changes
- File: `scripts/config/GameConfig.lua`
- Purpose: add progression tuning config for item unlock flow
- Details: added `RecipeProgression` parameters for xp, unlock thresholds, and cook batch caps
- Risk: config is groundwork until gameplay fully consumes these values
- Validation: reviewed against new progression helper usage

- File: `scripts/core/GameState.lua`
- Purpose: persist per-item progression data
- Details: added `itemProgress` state and included it in save serialization
- Risk: older saves will simply not have this field populated yet
- Validation: save path reviewed

- File: `scripts/core/ProgressionSystem.lua`
- Purpose: add helpers for sequential item unlock checks
- Details: added item xp query, unlock requirement calculation, unlock status helper, and fixed the missing-item fallback reason literal
- Risk: helper APIs still need broader gameplay integration to change item flow everywhere
- Validation: reviewed and checked with `git diff --check`

- File: `scripts/core/StallSystem.lua`
- Purpose: fix promotion cooldown timing
- Details: cooldown now ticks down even when no promotion is active, and promotion end no longer consumes cooldown immediately
- Risk: promotion availability timing changes by one settlement tick versus prior behavior
- Validation: cooldown guards cross-checked

- File: `scripts/scenes/CharacterRenderer.lua`
- Purpose: improve player weather visuals
- Details: added snowy outfit layers, rainy or stormy umbrella rendering, and reduced arm swing in harsh weather
- Risk: visual tuning still benefits from in-game review
- Validation: render diff reviewed

- File: `scripts/scenes/StallScene.lua`
- Purpose: improve pedestrian weather visuals
- Details: passed weather into spawned pedestrians and added snowy outfit layers with lower arm swing amplitude
- Risk: final polish still depends on in-game observation
- Validation: render diff reviewed

- File: `COLLABORATION.md`
- Purpose: keep the collaboration guide available in the repo
- Details: retained the shared project map, workflow notes, and log template for future work
- Risk: none at runtime
- Validation: documentation reviewed
