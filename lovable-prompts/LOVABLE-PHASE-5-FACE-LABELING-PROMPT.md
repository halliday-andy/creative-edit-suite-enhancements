# Phase 5: Face Labeling UI - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 5 of 7
**Duration:** 1 week
**Priority:** MEDIUM
**Depends On:** Phase 2 (Entity UI), Phase 4 (Face Detection)

---

## 🎯 Objective

Build UI for users to label face clusters with person entity names. Users can view unlabeled faces, select an entity (or create new), and link the cluster to that person.

---

## 📋 What to Build

### 1. New Page: `/faces` or tab in `/entities`

Face labeling interface showing unlabeled clusters.

### 2. Components (4 new)

1. **FaceClusterCard** - Shows representative face from cluster
2. **FaceLabelingModal** - Modal to assign entity to cluster
3. **EntityPickerDropdown** - Search/select entity with create option
4. **ClusterGallery** - Grid of all faces in cluster

---

## 🎨 UI Specifications

### FaceClusterCard

**Display:**
- Representative face thumbnail
- Face count (e.g., "12 occurrences")
- Label status badge (Unlabeled/Labeled/Under Review)
- "Label" button

### FaceLabelingModal

**Triggered by:** Clicking "Label" on FaceClusterCard

**Sections:**
1. **Face Gallery** - Show all faces in cluster (3x3 grid)
2. **Entity Picker** - Dropdown to search existing PERSON entities
3. **Create New** - Button to create new person entity
4. **Actions** - Save, Cancel buttons

---

## 🔧 Technical Implementation

### TypeScript Types

```typescript
export interface FaceCluster {
  id: string;
  cluster_key: string;
  status: 'unlabeled' | 'labeled' | 'under_review';
  entity_id: string | null;
  face_count: number;
  representative_face_url: string | null;
  created_at: string;
}
```

### Service Functions

```typescript
export const faceService = {
  async getUnlabeledClusters(): Promise<FaceCluster[]> {
    const { data, error } = await supabase
      .from('face_clusters')
      .select(`
        *,
        face_detections(count)
      `)
      .eq('status', 'unlabeled')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },

  async labelCluster(clusterId: string, entityId: string): Promise<void> {
    const { error } = await supabase
      .from('face_clusters')
      .update({
        entity_id: entityId,
        status: 'labeled'
      })
      .eq('id', clusterId);

    if (error) throw error;
  },

  async getClusterFaces(clusterId: string) {
    const { data, error } = await supabase
      .from('face_detections')
      .select('*')
      .eq('face_cluster_id', clusterId)
      .limit(20);

    if (error) throw error;
    return data || [];
  },
};
```

---

## ✅ Acceptance Criteria

- [ ] **Unlabeled clusters display** - Shows all clusters needing labels
- [ ] **Face gallery works** - Shows multiple faces from same cluster
- [ ] **Entity picker works** - Can search and select existing person
- [ ] **Create entity inline** - Can create new person from modal
- [ ] **Label assignment works** - Links cluster to entity correctly
- [ ] **Status updates** - Cluster status changes to "labeled"
- [ ] **Labeled clusters hidden** - Don't show in unlabeled view
- [ ] **Validation works** - Can't label as non-PERSON entity

### Test Cases:

1. **Label single cluster:**
   - View unlabeled clusters
   - Click "Label" on cluster
   - Select existing person "John Doe"
   - Verify cluster labeled and hidden from list

2. **Create person while labeling:**
   - Click "Label" on cluster
   - Click "Create New Person"
   - Enter name "Jane Smith"
   - Verify person created and cluster labeled

---

## ⏭️ Next Steps

After Phase 5:
1. ✅ Label 10+ clusters
2. ✅ Verify entities created correctly
3. ✅ Move to **Phase 6: Atom-Face Integration**

---

**Estimated Time:** 1 week (8-10 hours)
**Phase 5 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
