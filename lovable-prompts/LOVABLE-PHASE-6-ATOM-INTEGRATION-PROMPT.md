# Phase 6: Atom-Face Integration - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 6 of 7
**Duration:** 1 week  
**Priority:** MEDIUM
**Depends On:** Phase 3 (Atomization), Phase 5 (Face Labeling)

---

## 🎯 Objective

Integrate face detection data with atom timeline. When viewing atoms in editor, show which people are visible on screen (from face detection) in addition to who is mentioned in speech (from transcript).

---

## 📋 What to Build

### 1. Atom Enrichment Algorithm

Match face detections to atom time ranges:

```typescript
async function enrichAtomsWithFaces(clipId: string) {
  // Get all atoms for clip
  const { data: atoms } = await supabase
    .from('atoms')
    .select('*')
    .eq('clip_id', clipId);

  // Get face detections with entity labels
  const { data: faces } = await supabase
    .from('face_detections')
    .select(`
      *,
      face_cluster:face_clusters(
        entity_id,
        entity:entities(name, type)
      )
    `)
    .eq('clip_id', clipId);

  for (const atom of atoms) {
    // Find faces visible during this atom's time range
    const visibleFaces = faces.filter(face => 
      face.timestamp_seconds >= atom.start_time &&
      face.timestamp_seconds <= atom.end_time &&
      face.face_cluster?.entity_id
    );

    // Extract unique entities
    const visibleEntities = [...new Set(
      visibleFaces.map(f => f.face_cluster.entity_id)
    )];

    // Update atom metadata
    const updatedMetadata = {
      ...atom.metadata,
      visible_entities: visibleEntities,
      face_count: visibleFaces.length,
    };

    await supabase
      .from('atoms')
      .update({ metadata: updatedMetadata })
      .eq('id', atom.id);
  }
}
```

### 2. Auto-Enrichment Trigger

**Create database trigger:**
```sql
CREATE OR REPLACE FUNCTION enrich_atoms_on_face_label()
RETURNS TRIGGER AS $$
BEGIN
  -- When a face cluster gets labeled,
  -- trigger atom enrichment for all affected clips
  PERFORM enrich_atoms_with_faces(
    (SELECT DISTINCT clip_id FROM face_detections 
     WHERE face_cluster_id = NEW.id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_enrich_atoms
AFTER UPDATE OF entity_id ON face_clusters
FOR EACH ROW
WHEN (OLD.entity_id IS DISTINCT FROM NEW.entity_id)
EXECUTE FUNCTION enrich_atoms_on_face_label();
```

### 3. UI Updates

**Update Atom Display:**
- Show visible entities alongside mentioned entities
- Icon: 👁️ for visible, 🗣️ for mentioned
- Different colors or badges

---

## ✅ Acceptance Criteria

- [ ] **Atom enrichment works** - Atoms updated with visible_entities
- [ ] **Auto-enrichment triggers** - Runs when cluster labeled
- [ ] **UI shows visible people** - Editor displays who is on screen
- [ ] **Mentioned vs visible clear** - Easy to distinguish audio vs visual
- [ ] **Performance acceptable** - Enrichment completes within 5 seconds
- [ ] **Handles edge cases** - Works when no faces or no labels

---

## ⏭️ Next Steps

After Phase 6:
1. ✅ Test with labeled clips
2. ✅ Verify atoms enriched correctly
3. ✅ Move to **Phase 7: Enhanced Search**

---

**Estimated Time:** 1 week (6-8 hours)
**Phase 6 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
