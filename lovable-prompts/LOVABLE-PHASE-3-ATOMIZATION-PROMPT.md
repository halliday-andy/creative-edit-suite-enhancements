# Phase 3: Entity-Aware Atomization - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 3 of 7
**Duration:** 1 week
**Priority:** HIGH
**Depends On:** Phase 1 (Database), Phase 2 (Entity UI)

---

## 🎯 Objective

Modify the atomization process to be entity-aware. When Gemini analyzes transcripts and creates atoms, it should identify entities (people, locations, objects, concepts) mentioned in each atom and link them to the knowledge graph.

**This phase modifies the backend processing - no new UI components.**

---

## 📋 What to Build

### 1. Update Atomization Edge Function

**File:** `/supabase/functions/analyze-atoms/index.ts`

**Changes:**
1. Pass entity context to Gemini
2. Extract entity references from Gemini response
3. Link atoms to entities via `clip_entities` table
4. Generate embeddings for fuzzy matching

### 2. Entity Context Injection

**Before Gemini analyzes transcript:**
```typescript
// Fetch existing entities
const { data: entities } = await supabase
  .from('entities')
  .select('id, name, type, description, aliases');

// Build context string
const entityContext = `
Known Entities:
${entities.map(e => `- ${e.name} (${e.type}): ${e.description || 'N/A'}`).join('\n')}

When analyzing this transcript, identify which of these entities are mentioned or relevant to each atom.
`;
```

### 3. Gemini Prompt Enhancement

Update the atomization prompt to include:
```
For each atom, identify:
1. Which entities from the known entities list are mentioned
2. What role each entity plays (subject, mentioned, related)
3. Confidence score (0-1) for each entity link

Return entity references in this format:
{
  "entities": [
    {
      "name": "Entity Name",
      "relationship_type": "subject|mentioned|related",
      "confidence": 0.95,
      "context": "Why this entity is relevant"
    }
  ]
}
```

### 4. Entity Matching Algorithm

**Fuzzy Matching Logic:**
```typescript
async function findOrCreateEntity(
  entityName: string,
  type: EntityType,
  description?: string
): Promise<string> {
  // 1. Try exact name match
  let { data: entity } = await supabase
    .from('entities')
    .select('id')
    .eq('name', entityName)
    .eq('type', type)
    .single();

  if (entity) return entity.id;

  // 2. Try alias match
  const { data: aliasMatch } = await supabase
    .from('entities')
    .select('id')
    .contains('aliases', [entityName])
    .eq('type', type)
    .single();

  if (aliasMatch) return aliasMatch.id;

  // 3. Try case-insensitive match
  const { data: fuzzyMatch } = await supabase
    .from('entities')
    .select('id')
    .ilike('name', entityName)
    .eq('type', type)
    .single();

  if (fuzzyMatch) return fuzzyMatch.id;

  // 4. Create new entity if confidence > 0.8
  const { data: newEntity } = await supabase
    .from('entities')
    .insert({
      name: entityName,
      type: type,
      description: description || null,
    })
    .select('id')
    .single();

  return newEntity.id;
}
```

### 5. Link Entities to Clip

After creating atoms:
```typescript
for (const atomData of atoms) {
  for (const entityRef of atomData.entities || []) {
    const entityId = await findOrCreateEntity(
      entityRef.name,
      entityRef.type || 'CONCEPT',
      entityRef.context
    );

    await supabase
      .from('clip_entities')
      .insert({
        clip_id: clipId,
        entity_id: entityId,
        relationship_type: entityRef.relationship_type,
        confidence: entityRef.confidence,
        context: entityRef.context,
      });
  }
}
```

---

## ✅ Acceptance Criteria

- [ ] **Entity context passed to Gemini** - Existing entities included in prompt
- [ ] **Entity references extracted** - Gemini response includes entity mentions
- [ ] **Fuzzy matching works** - Can match variations of entity names
- [ ] **New entities auto-created** - Unknown entities added to knowledge graph (confidence > 0.8)
- [ ] **Clip-entity links created** - clip_entities table populated correctly
- [ ] **Relationship types correct** - subject, mentioned, related assigned properly
- [ ] **Confidence scores stored** - Values between 0-1
- [ ] **Existing atomization still works** - No breaking changes to core functionality
- [ ] **Performance acceptable** - Processing time < 2x slower than before
- [ ] **Error handling** - Gracefully handles Gemini response errors

### Test Cases:

1. **Process clip mentioning known entity:**
   - Create entity "John Doe" (PERSON)
   - Process clip transcript: "John Doe explained the strategy"
   - Verify clip_entities link created
   - Verify relationship_type = "subject"

2. **Process clip mentioning unknown entity:**
   - Process clip: "We visited Paris last week"
   - Verify "Paris" auto-created as LOCATION entity
   - Verify clip_entities link created

3. **Process clip with multiple entities:**
   - Process clip: "John and Sarah met in New York"
   - Verify 3 entities linked (John, Sarah, New York)
   - Verify correct types (PERSON, PERSON, LOCATION)

---

## 📚 Reference Documents

1. **entity-aware-atomization-spec.md** - Detailed specifications
2. **LOVABLE-IMPLEMENTATION-PROMPT.md** - Phase 3 section

---

## ⏭️ Next Steps

After Phase 3 completion:
1. ✅ Test with 5-10 different clips
2. ✅ Verify entity auto-creation works
3. ✅ Check entity relationships are accurate
4. ✅ Move to **Phase 4: Face Detection & Clustering**

---

**Estimated Time:** 1 week (6-10 hours)
**Phase 3 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
