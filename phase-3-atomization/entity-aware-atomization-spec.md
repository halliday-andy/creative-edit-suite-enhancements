# Entity-Aware Atomization Specification

## Overview

This document specifies how to modify the Creative Edit Suite atomization Edge Function to integrate entity tracking and knowledge graph capabilities. The enhanced atomization process will fetch existing entities, provide them as context to Gemini, and store entity references in atoms for semantic search.

## Current Atomization Flow (Lovable)

```
1. Upload video → clips table record created
2. Transcribe audio → ElevenLabs Scribe returns word-level transcript
3. Atomize video:
   - Gemini analyzes transcript + video
   - Returns atoms with start_word_index/end_word_index
   - Atoms stored in clips.atoms_data JSONB
4. Generate embeddings → OpenAI embeddings for semantic search
5. Mark clip as 'ready'
```

## Enhanced Flow with Entity System

```
1. Upload video → clips table record created
2. Transcribe audio → ElevenLabs Scribe returns word-level transcript
3. **Fetch existing entities** → Query entities table
4. Atomize video:
   - **Provide entity list to Gemini** (names + UUIDs + types)
   - Gemini analyzes transcript + video + entity context
   - Returns atoms with start_word_index/end_word_index + **entity references**
   - Atoms stored in clips.atoms_data JSONB with subject_entity_id/object_entity_id
5. **Create clip_entities records** → Aggregate entity mentions from atoms
6. Generate embeddings → OpenAI embeddings for semantic search
7. Mark clip as 'ready'
```

## Step-by-Step Implementation

### Step 1: Fetch Existing Entities

**Location:** `supabase/functions/process-video/atomization.ts`

**Before atomization begins:**

```typescript
// Fetch all entities from database
const { data: entities, error: entitiesError } = await supabaseClient
  .from('entities')
  .select('id, name, type, aliases')
  .order('name');

if (entitiesError) {
  console.error('Failed to fetch entities:', entitiesError);
  // Continue without entities - graceful degradation
}

// Format entities for Gemini prompt
const entityContext = entities?.map(e => ({
  name: e.name,
  uuid: e.id,
  type: e.type,
  aliases: e.aliases || []
})) || [];
```

### Step 2: Enhanced Gemini Prompt with Entity Context

**Modify the atomization prompt to include entity context:**

```typescript
const atomizationPrompt = `
SYSTEM: You are a Behavioral Psychologist AND Cinematographer analyzing video content.

TASK: Extract searchable "Atoms" from this video clip.

TRANSCRIPT (with word indices):
${transcriptWithIndices}

CLIP DURATION: ${duration} seconds

**KNOWN ENTITIES IN SYSTEM:**
${formatEntitiesForPrompt(entityContext)}

**ENTITY MATCHING RULES:**
- If you identify a person, location, object, or concept that matches a known entity, use its UUID
- Subject entities go in "subject_entity_id"
- Object entities go in "object_entity_id"
- Always provide fallback text in "subject_text" and "object_text" even when you have entity IDs
- If no entity match, set entity_id to null but provide descriptive text
- Only use EXACT matches - don't guess or approximate

OUTPUT SCHEMA (JSON):
{
  "atoms": [
    {
      "start_word_index": 142,
      "end_word_index": 158,
      "subject_entity_id": "e88f7a2d-...", // UUID of entity or null
      "subject_text": "Kara", // Always provide fallback text
      "action": "Hesitates to eat",
      "object_entity_id": "a1b2c3d4-...", // UUID of entity or null
      "object_text": "live octopus tentacle",
      ...rest of atom fields...
    }
  ]
}

GUIDELINES:
- Prioritize entity matching for people, key locations, and recurring objects/concepts
- Be conservative - only match entities when you're confident
- Prefer existing entities over creating implicit new ones
- Include entity UUIDs when matched, null when not matched
`;

function formatEntitiesForPrompt(entities: Array<{name: string; uuid: string; type: string; aliases: string[]}>): string {
  if (entities.length === 0) {
    return "No entities in system yet - identify subjects/objects by descriptive text only";
  }

  return entities.map(e => {
    const aliasText = e.aliases.length > 0 ? ` (aliases: ${e.aliases.join(', ')})` : '';
    return `- ${e.name} [${e.type}] → UUID: ${e.uuid}${aliasText}`;
  }).join('\n');
}
```

### Step 3: Process Gemini Response with Entity References

**Validate and store entity references in atoms_data:**

```typescript
// Validate Gemini response
const atoms = geminiResponse.atoms.map((atom: any) => ({
  start_word_index: atom.start_word_index,
  end_word_index: atom.end_word_index,

  // Entity references (NEW)
  subject_entity_id: validateUUID(atom.subject_entity_id) ? atom.subject_entity_id : null,
  subject_text: atom.subject_text || 'Unknown subject',

  object_entity_id: validateUUID(atom.object_entity_id) ? atom.object_entity_id : null,
  object_text: atom.object_text || null,

  // Rest of atom fields
  action: atom.action,
  thought_signature: atom.thought_signature,
  emotion: atom.emotion,
  emotional_valence: atom.emotional_valence,
  emotion_intensity: atom.emotion_intensity,
  transcript_excerpt: atom.transcript_excerpt,
  search_keywords: atom.search_keywords || []
}));

// Store in clips.atoms_data JSONB
const { error: updateError } = await supabaseClient
  .from('clips')
  .update({ atoms_data: atoms })
  .eq('id', clipId);
```

### Step 4: Create clip_entities Records

**After atomization, aggregate entity mentions and create clip_entities records:**

```typescript
// Aggregate entity mentions from atoms
interface EntityMention {
  entityId: string;
  role: string; // 'subject' or 'object'
  firstAppearance: number; // seconds
  count: number;
}

const entityMentions = new Map<string, EntityMention>();

for (const atom of atoms) {
  const startTimeSeconds = calculateTimestamp(atom.start_word_index, transcript);

  // Track subject entities
  if (atom.subject_entity_id) {
    const existing = entityMentions.get(atom.subject_entity_id);
    if (existing) {
      existing.count++;
      existing.firstAppearance = Math.min(existing.firstAppearance, startTimeSeconds);
    } else {
      entityMentions.set(atom.subject_entity_id, {
        entityId: atom.subject_entity_id,
        role: 'subject',
        firstAppearance: startTimeSeconds,
        count: 1
      });
    }
  }

  // Track object entities
  if (atom.object_entity_id) {
    const existing = entityMentions.get(atom.object_entity_id);
    if (existing) {
      existing.count++;
      existing.firstAppearance = Math.min(existing.firstAppearance, startTimeSeconds);
      if (existing.role === 'subject') {
        existing.role = 'both'; // Entity is both subject and object
      }
    } else {
      entityMentions.set(atom.object_entity_id, {
        entityId: atom.object_entity_id,
        role: 'object',
        firstAppearance: startTimeSeconds,
        count: 1
      });
    }
  }
}

// Insert clip_entities records
const clipEntityRecords = Array.from(entityMentions.values()).map(mention => ({
  clip_id: clipId,
  entity_id: mention.entityId,
  role: mention.role,
  first_appearance_seconds: mention.firstAppearance,
  mention_count: mention.count,
  confidence: 1.0 // High confidence for manual entity matches
}));

if (clipEntityRecords.length > 0) {
  const { error: insertError } = await supabaseClient
    .from('clip_entities')
    .insert(clipEntityRecords);

  if (insertError) {
    console.error('Failed to insert clip_entities:', insertError);
    // Non-fatal - continue processing
  } else {
    console.log(`Created ${clipEntityRecords.length} clip_entity records`);
  }
}
```

### Step 5: Update First Seen References

**Update entity.first_seen_clip_id for newly seen entities:**

```typescript
// For each entity in this clip, check if this is their first appearance
for (const mention of entityMentions.values()) {
  const { data: entity } = await supabaseClient
    .from('entities')
    .select('first_seen_clip_id, created_at')
    .eq('id', mention.entityId)
    .single();

  // If entity has no first_seen_clip_id OR this clip is older, update it
  if (entity && !entity.first_seen_clip_id) {
    await supabaseClient
      .from('entities')
      .update({ first_seen_clip_id: clipId })
      .eq('id', mention.entityId);

    console.log(`Set first_seen_clip_id for entity ${mention.entityId}`);
  }
}
```

## Error Handling and Edge Cases

### Graceful Degradation

```typescript
// If entity fetch fails, continue without entities
if (!entities || entities.length === 0) {
  console.warn('No entities available - atomization will proceed without entity context');
  // Gemini prompt will note "No entities in system yet"
  // Atoms will have null entity_id fields but descriptive text
}
```

### Invalid Entity UUIDs

```typescript
function validateUUID(uuid: any): boolean {
  if (!uuid || typeof uuid !== 'string') return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}

// If Gemini returns invalid UUID, set to null and log warning
if (atom.subject_entity_id && !validateUUID(atom.subject_entity_id)) {
  console.warn(`Invalid subject_entity_id from Gemini: ${atom.subject_entity_id}`);
  atom.subject_entity_id = null;
}
```

### Entity Not Found

```typescript
// Before inserting clip_entities, verify entities exist
const entityIds = Array.from(entityMentions.keys());
const { data: existingEntities } = await supabaseClient
  .from('entities')
  .select('id')
  .in('id', entityIds);

const validEntityIds = new Set(existingEntities?.map(e => e.id) || []);

// Filter to only valid entity IDs
const validClipEntityRecords = clipEntityRecords.filter(record =>
  validEntityIds.has(record.entity_id)
);

if (validClipEntityRecords.length < clipEntityRecords.length) {
  console.warn(`Filtered out ${clipEntityRecords.length - validClipEntityRecords.length} invalid entity references`);
}
```

## Testing Strategy

### Unit Tests

```typescript
// Test entity context formatting
describe('formatEntitiesForPrompt', () => {
  it('should format entities with UUIDs and aliases', () => {
    const entities = [
      { name: 'Kara', uuid: '123-456', type: 'PERSON', aliases: ['Kara Smith'] },
      { name: 'Seoul', uuid: '789-012', type: 'LOCATION', aliases: [] }
    ];
    const result = formatEntitiesForPrompt(entities);
    expect(result).toContain('Kara [PERSON] → UUID: 123-456 (aliases: Kara Smith)');
    expect(result).toContain('Seoul [LOCATION] → UUID: 789-012');
  });

  it('should handle empty entity list', () => {
    const result = formatEntitiesForPrompt([]);
    expect(result).toBe('No entities in system yet - identify subjects/objects by descriptive text only');
  });
});

// Test entity mention aggregation
describe('aggregateEntityMentions', () => {
  it('should count mentions and track first appearance', () => {
    const atoms = [
      { subject_entity_id: 'abc', start_word_index: 10 },
      { subject_entity_id: 'abc', start_word_index: 50 },
      { object_entity_id: 'abc', start_word_index: 30 }
    ];
    const mentions = aggregateEntityMentions(atoms, transcript);
    expect(mentions.get('abc').count).toBe(3);
    expect(mentions.get('abc').role).toBe('both');
  });
});
```

### Integration Tests

```typescript
// Test end-to-end atomization with entities
describe('Entity-aware atomization', () => {
  beforeAll(async () => {
    // Create test entities
    await supabase.from('entities').insert([
      { name: 'Test Person', type: 'PERSON' },
      { name: 'Test Location', type: 'LOCATION' }
    ]);
  });

  it('should create atoms with entity references', async () => {
    const clipId = await uploadTestClip();
    await processClip(clipId);

    const { data: clip } = await supabase
      .from('clips')
      .select('atoms_data')
      .eq('id', clipId)
      .single();

    expect(clip.atoms_data).toBeDefined();
    expect(clip.atoms_data.some(atom => atom.subject_entity_id !== null)).toBe(true);
  });

  it('should create clip_entities records', async () => {
    const clipId = await uploadTestClip();
    await processClip(clipId);

    const { data: clipEntities } = await supabase
      .from('clip_entities')
      .select('*')
      .eq('clip_id', clipId);

    expect(clipEntities.length).toBeGreaterThan(0);
    expect(clipEntities[0]).toHaveProperty('mention_count');
    expect(clipEntities[0]).toHaveProperty('first_appearance_seconds');
  });
});
```

## Performance Considerations

### Entity List Caching

```typescript
// Cache entity list in Edge Function memory (5 min TTL)
let cachedEntities: Array<{name: string; uuid: string; type: string}> | null = null;
let cacheTimestamp = 0;
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

async function getEntitiesWithCache(supabase: SupabaseClient) {
  const now = Date.now();
  if (cachedEntities && (now - cacheTimestamp) < CACHE_TTL_MS) {
    return cachedEntities;
  }

  const { data, error } = await supabase
    .from('entities')
    .select('id, name, type, aliases');

  if (!error && data) {
    cachedEntities = data;
    cacheTimestamp = now;
  }

  return data || [];
}
```

### Batch Operations

```typescript
// Insert all clip_entities in single batch operation
await supabaseClient
  .from('clip_entities')
  .insert(clipEntityRecords); // Batch insert

// Update multiple entity first_seen_clip_id in batch
const entityUpdates = unseenEntityIds.map(id => ({
  id,
  first_seen_clip_id: clipId
}));

await supabaseClient
  .from('entities')
  .upsert(entityUpdates);
```

## Migration Path for Existing Clips

### Background Re-processing Job

```typescript
// Script to re-process existing clips with entity awareness
// Run as scheduled Edge Function or admin script

export async function reprocessClipsWithEntities() {
  const { data: clips } = await supabase
    .from('clips')
    .select('id, atoms_data')
    .eq('status', 'ready')
    .is('atoms_data', 'not.null');

  for (const clip of clips || []) {
    // Check if atoms already have entity references
    const hasEntityRefs = clip.atoms_data?.some(
      atom => atom.subject_entity_id || atom.object_entity_id
    );

    if (!hasEntityRefs) {
      console.log(`Re-processing clip ${clip.id} with entity awareness`);
      await reprocessClip(clip.id);

      // Rate limit to avoid overwhelming system
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
}
```

## Success Metrics

- **Entity coverage:** 80%+ of clips have at least one entity reference
- **Entity matching accuracy:** Manual review shows 95%+ correct entity matches
- **Performance impact:** Entity-aware atomization adds < 2 seconds per clip
- **clip_entities records:** Average 2-5 entities per clip (varies by content)

## Rollback Plan

If entity-aware atomization causes issues:

1. **Immediate:** Revert Edge Function to previous version (disable entity fetching)
2. **Data preservation:** clip_entities table remains intact, can be re-populated later
3. **Graceful degradation:** Existing atoms without entity_id fields continue to work
4. **Cleanup:** Run migration rollback script to remove entity tables if needed

## Next Steps

1. Implement entity-aware atomization in Edge Function
2. Test with sample clips containing known entities
3. Monitor Gemini entity matching accuracy
4. Create entity management UI for manual entity creation
5. Add entity filters to search interface
