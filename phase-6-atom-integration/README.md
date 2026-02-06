# Phase 6: Atom-Face Integration

**Priority:** MEDIUM | **Duration:** 1 week

## Overview

Enrich atoms with face detection data, showing both audio entities (who is speaking/mentioned) and visual entities (who is visible on screen).

## What's Included

- [`face-labeling-atom-integration-spec.md`](./face-labeling-atom-integration-spec.md) - Complete integration architecture

## What You'll Build

### Edge Function
- `supabase/functions/enrich-atoms-with-faces/index.ts`

### Process
1. For each atom, calculate time range from word indices
2. Query face_detections where timestamp overlaps atom
3. Add `visible_entities` array to atom
4. Merge with audio entities to create `all_entities`
5. Update clips.atoms_data JSONB

### Enhanced Atom Schema
```typescript
{
  // ... existing atom fields
  visible_entities: [
    {
      entity_id: "uuid",
      entity_name: "Kara Smith",
      source: "face_detection",
      confidence: 0.95,
      appearance_count: 3
    }
  ],
  all_entities: [
    { entity_id, role: "subject", source: "audio" },
    { entity_id, role: "visible", source: "visual" }
  ]
}
```

### UI Updates
- AtomInspector shows visible_entities
- Entity chips show source badges (🎧 audio, 📹 video)
- Face timeline shows when each person appears

## Prerequisites

- Phase 3 (Entity-Aware Atomization) complete
- Phase 5 (Face Labeling UI) complete
- Faces labeled and linked to entities

## Acceptance Criteria

- [ ] Atoms enriched with visible_entities
- [ ] Audio and visual entities merged correctly
- [ ] AtomInspector displays both sources
- [ ] Entity source badges render
- [ ] Face timeline works
- [ ] Automatic enrichment after labeling

## Next Phase

After completing Phase 6, move to [Phase 7: Enhanced Search](../phase-7-search/)
