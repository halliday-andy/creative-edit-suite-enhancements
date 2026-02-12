# Phase 7: Enhanced Search - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 7 of 7
**Duration:** 1 week
**Priority:** LOW (Nice to have)
**Depends On:** All previous phases

---

## 🎯 Objective

Add entity-based search capabilities. Users can search for clips by person name, location, or other entities. Uses both semantic search (embeddings) and exact matching.

---

## 📋 What to Build

### 1. Entity Search Bar

**Add to existing search page:**
- Entity filter chips
- Multi-select entity dropdown
- "Any of these entities" vs "All of these entities" toggle

### 2. Search Service Enhancement

```typescript
export const searchService = {
  async searchByEntities(
    entityIds: string[],
    matchMode: 'any' | 'all' = 'any'
  ) {
    if (matchMode === 'any') {
      // Return clips linked to ANY of these entities
      const { data, error } = await supabase
        .from('clip_entities')
        .select(`
          clip_id,
          clip:clips(*)
        `)
        .in('entity_id', entityIds);

      return data?.map(ce => ce.clip) || [];
    } else {
      // Return clips linked to ALL of these entities
      // Requires more complex query or post-processing
    }
  },

  async semanticSearchWithEntities(
    query: string,
    entityFilter?: string[]
  ) {
    // Generate query embedding
    const embedding = await generateEmbedding(query);

    // Search atoms with optional entity filter
    let query = supabase
      .rpc('search_atoms_with_embedding', {
        query_embedding: embedding,
        match_threshold: 0.7,
        match_count: 50
      });

    if (entityFilter && entityFilter.length > 0) {
      // Filter by clips that have these entities
      const clipIds = await getClipIdsWithEntities(entityFilter);
      query = query.in('clip_id', clipIds);
    }

    const { data, error } = await query;
    return data || [];
  },
};
```

### 3. RPC Function

**Create in migration:**
```sql
CREATE OR REPLACE FUNCTION search_clips_by_entities(
  entity_ids UUID[],
  match_mode TEXT DEFAULT 'any'
)
RETURNS TABLE (
  clip_id UUID,
  entity_count BIGINT,
  max_confidence NUMERIC
) AS $$
BEGIN
  IF match_mode = 'any' THEN
    RETURN QUERY
    SELECT ce.clip_id, COUNT(*)::BIGINT, MAX(ce.confidence)
    FROM clip_entities ce
    WHERE ce.entity_id = ANY(entity_ids)
    GROUP BY ce.clip_id
    ORDER BY COUNT(*) DESC, MAX(ce.confidence) DESC;
  ELSE
    -- 'all' mode
    RETURN QUERY
    SELECT ce.clip_id, COUNT(DISTINCT ce.entity_id)::BIGINT, MAX(ce.confidence)
    FROM clip_entities ce
    WHERE ce.entity_id = ANY(entity_ids)
    GROUP BY ce.clip_id
    HAVING COUNT(DISTINCT ce.entity_id) = array_length(entity_ids, 1)
    ORDER BY MAX(ce.confidence) DESC;
  END IF;
END;
$$ LANGUAGE plpgsql;
```

---

## ✅ Acceptance Criteria

- [ ] **Entity search works** - Can search by entity name
- [ ] **Multi-entity search works** - Can filter by multiple entities
- [ ] **"Any" mode works** - Returns clips with any selected entity
- [ ] **"All" mode works** - Returns clips with all selected entities
- [ ] **Semantic search enhanced** - Entity filter narrows results
- [ ] **Fast performance** - Search returns in < 2 seconds
- [ ] **UI intuitive** - Easy to add/remove entity filters

### Test Cases:

1. **Search by single entity:**
   - Select "John Doe"
   - Verify returns only clips with John Doe

2. **Search by multiple (ANY):**
   - Select "John Doe" and "Jane Smith"
   - Mode: ANY
   - Verify returns clips with John OR Jane

3. **Search by multiple (ALL):**
   - Select "John Doe" and "San Francisco"
   - Mode: ALL
   - Verify returns only clips with BOTH

---

## 🎉 Project Complete!

After Phase 7, the entity and facial recognition system is fully implemented!

**Next:** Begin user testing and gather feedback.

---

**Estimated Time:** 1 week (6-8 hours)
**Phase 7 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
