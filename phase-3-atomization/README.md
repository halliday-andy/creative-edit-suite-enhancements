# Phase 3: Entity-Aware Atomization

**Priority:** HIGH | **Duration:** 1 week

## Overview

Modify the video processing pipeline to include entity context during atomization, enabling Gemini to link atoms to known entities.

## What's Included

- [`entity-aware-atomization-spec.md`](./entity-aware-atomization-spec.md) - Processing pipeline modifications

## What You'll Modify

### Edge Function
- `supabase/functions/process-video/atomization.ts`

### Changes
1. Fetch existing entities before atomization
2. Include entity context in Gemini prompt
3. Store entity references in atoms (subject_entity_id, object_entity_id)
4. Create clip_entities records after atomization

### New Data Fields
```typescript
{
  start_word_index: 142,
  end_word_index: 158,
  subject_entity_id: "uuid",  // NEW
  subject_text: "Kara",
  object_entity_id: "uuid",   // NEW
  object_text: "octopus",
  action: "Hesitates to eat",
  // ... rest of atom fields
}
```

## Prerequisites

- Phase 1 (Database Foundation) complete
- Existing atomization Edge Function working
- Access to Gemini API

## Acceptance Criteria

- [ ] Entities fetched before atomization
- [ ] Gemini receives entity context in prompt
- [ ] Atoms include entity_id references
- [ ] clip_entities table populated
- [ ] No errors in processing pipeline

## Next Phase

After completing Phase 3, you have a working MVP! 

Move to [Phase 4: Face Detection](../phase-4-face-detection/) to add facial recognition.
