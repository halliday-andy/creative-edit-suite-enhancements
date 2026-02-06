# Face Labeling → Atom Integration & Search Architecture

## Overview

This document specifies the complete data flow from face detection through labeling to atom enrichment, ensuring that:

1. **Face labels propagate to atoms** - When a user labels a face, all atoms featuring that person are updated
2. **Atoms display person entities** - The editor UI shows which people appear in each atom
3. **Search includes face data** - Users can search for clips by person across all processed videos
4. **New videos auto-recognize faces** - Newly uploaded videos automatically identify previously labeled people

## Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ 1. VIDEO UPLOAD & PROCESSING                                │
│    ├─ Video uploaded → clips table                          │
│    ├─ Transcription → ElevenLabs word-level data            │
│    ├─ Atomization → atoms_data JSONB created                │
│    └─ Face detection → face_detections table created        │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 2. FACE CLUSTERING                                           │
│    ├─ Group face_detections by embedding similarity         │
│    ├─ Create face_clusters for unique individuals           │
│    └─ Check if faces match existing labeled clusters        │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 3. USER LABELING (Manual for new faces)                     │
│    ├─ Present unlabeled faces to user                       │
│    ├─ User selects existing entity OR creates new           │
│    └─ Link face_cluster → entity_id                         │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. ATOM ENRICHMENT (Automatic propagation)                  │
│    ├─ Query face_detections for atom time ranges            │
│    ├─ Identify which faces appear in each atom              │
│    ├─ Update atoms_data JSONB with entity references        │
│    └─ Store in clips table                                  │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 5. CLIP ENTITY AGGREGATION                                  │
│    ├─ Aggregate all entities from atoms + faces             │
│    ├─ Update clip_entities table                            │
│    └─ Update clips.face_coordinates JSONB                   │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 6. SEARCH INDEXING                                          │
│    ├─ Update entity search indices                          │
│    ├─ Enable face-based clip filtering                      │
│    └─ Cache entity → clips mapping                          │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 7. FUTURE VIDEO AUTO-LABELING                               │
│    ├─ New video uploaded                                    │
│    ├─ Face detection runs                                   │
│    ├─ Compare embeddings to existing face_clusters          │
│    └─ Auto-assign entity_id if match found (>0.6 similarity)│
└──────────────────────────────────────────────────────────────┘
```

## Step 4: Atom Enrichment Details

### Problem Statement

After a user labels faces, we need to:
1. Determine which atoms contain each labeled person
2. Update the atom data to include entity references
3. Make this data available to the editor UI
4. Ensure search can filter by these entities

### Solution Architecture

#### 4.1 Spatial-Temporal Atom-Face Matching

An atom is defined by:
- `start_word_index` and `end_word_index` (which map to timestamps via transcript)
- Action/subject/object descriptions

A face detection is defined by:
- `timestamp_seconds` (when face appears)
- `bbox` (where on screen)
- `entity_id` (after labeling)

**Matching algorithm:**

```typescript
// Edge Function: enrich-atoms-with-faces

interface AtomFaceMatch {
  atom_index: number;
  entity_id: string;
  entity_name: string;
  confidence: number;
  appearance_count: number; // How many times face appears during atom
}

async function enrichAtomsWithFaces(clipId: string) {
  const supabase = createClient(...);

  // 1. Fetch clip data
  const { data: clip } = await supabase
    .from('clips')
    .select('atoms_data, duration')
    .eq('id', clipId)
    .single();

  // 2. Fetch transcript for timestamp calculation
  const { data: transcript } = await supabase
    .from('transcripts')
    .select('words')
    .eq('clip_id', clipId)
    .single();

  // 3. Fetch all face detections for this clip (only labeled ones)
  const { data: faceDetections } = await supabase
    .from('face_detections')
    .select(`
      timestamp_seconds,
      entity_id,
      confidence,
      entities (name)
    `)
    .eq('clip_id', clipId)
    .not('entity_id', 'is', null); // Only labeled faces

  if (!faceDetections || faceDetections.length === 0) {
    console.log('No labeled faces to enrich atoms');
    return;
  }

  // 4. For each atom, find which faces appear during its time range
  const enrichedAtoms = clip.atoms_data.map((atom, index) => {
    // Calculate atom time range from word indices
    const startTime = transcript.words[atom.start_word_index]?.start || 0;
    const endTime = transcript.words[atom.end_word_index]?.end || 0;

    // Find faces that appear during this atom
    const facesInAtom = faceDetections.filter(face =>
      face.timestamp_seconds >= startTime &&
      face.timestamp_seconds <= endTime
    );

    // Group by entity
    const entitiesInAtom = new Map<string, {
      entity_id: string;
      entity_name: string;
      appearances: number;
      avg_confidence: number;
    }>();

    for (const face of facesInAtom) {
      const existing = entitiesInAtom.get(face.entity_id);
      if (existing) {
        existing.appearances++;
        existing.avg_confidence = (existing.avg_confidence + face.confidence) / 2;
      } else {
        entitiesInAtom.set(face.entity_id, {
          entity_id: face.entity_id,
          entity_name: face.entities.name,
          appearances: 1,
          avg_confidence: face.confidence
        });
      }
    }

    // Add face data to atom
    return {
      ...atom,
      visible_entities: Array.from(entitiesInAtom.values()).map(e => ({
        entity_id: e.entity_id,
        entity_name: e.entity_name,
        entity_type: 'PERSON',
        source: 'face_detection',
        confidence: e.avg_confidence,
        appearance_count: e.appearances
      }))
    };
  });

  // 5. Update clips.atoms_data with enriched data
  await supabase
    .from('clips')
    .update({ atoms_data: enrichedAtoms })
    .eq('id', clipId);

  console.log(`Enriched ${enrichedAtoms.length} atoms with face data`);
}
```

#### 4.2 Merging Audio and Visual Entity Data

Atoms may already have entity references from audio (transcript-based atomization). We need to merge:
- **Audio entities:** From `subject_entity_id`, `object_entity_id` (mentioned in speech)
- **Visual entities:** From face detection (visible on screen)

```typescript
interface EnrichedAtom {
  // Original atom fields
  start_word_index: number;
  end_word_index: number;
  action: string;

  // Audio-based entities (from transcript/Gemini)
  subject_entity_id?: string;
  subject_text?: string;
  object_entity_id?: string;
  object_text?: string;

  // Visual entities (from face detection) - NEW
  visible_entities: Array<{
    entity_id: string;
    entity_name: string;
    entity_type: 'PERSON';
    source: 'face_detection';
    confidence: number;
    appearance_count: number;
  }>;

  // Merged view for UI
  all_entities: Array<{
    entity_id: string;
    entity_name: string;
    role: 'subject' | 'object' | 'visible'; // How entity relates to atom
    source: 'audio' | 'visual';
    confidence: number;
  }>;
}

function mergeEntitySources(atom: any, faceEntities: any[]): EnrichedAtom {
  const allEntities = [];

  // Add audio entities
  if (atom.subject_entity_id) {
    allEntities.push({
      entity_id: atom.subject_entity_id,
      entity_name: atom.subject_text,
      role: 'subject',
      source: 'audio',
      confidence: 1.0
    });
  }

  if (atom.object_entity_id) {
    allEntities.push({
      entity_id: atom.object_entity_id,
      entity_name: atom.object_text,
      role: 'object',
      source: 'audio',
      confidence: 1.0
    });
  }

  // Add visual entities (deduplicate if already in audio)
  for (const faceEntity of faceEntities) {
    const alreadyIncluded = allEntities.some(
      e => e.entity_id === faceEntity.entity_id
    );

    if (!alreadyIncluded) {
      allEntities.push({
        entity_id: faceEntity.entity_id,
        entity_name: faceEntity.entity_name,
        role: 'visible',
        source: 'visual',
        confidence: faceEntity.confidence
      });
    }
  }

  return {
    ...atom,
    visible_entities: faceEntities,
    all_entities: allEntities
  };
}
```

## Step 5: Editor UI Display

### Atom Inspector Enhancement

```tsx
// src/components/atoms/AtomInspector.tsx

interface AtomWithEntities {
  // ... existing atom fields
  visible_entities?: Array<{
    entity_id: string;
    entity_name: string;
    entity_type: string;
    source: 'face_detection';
    confidence: number;
    appearance_count: number;
  }>;
  all_entities?: Array<{
    entity_id: string;
    entity_name: string;
    role: 'subject' | 'object' | 'visible';
    source: 'audio' | 'visual';
    confidence: number;
  }>;
}

export default function AtomInspector({ atom }: { atom: AtomWithEntities }) {
  return (
    <div className="space-y-4">
      {/* Existing atom fields: action, emotion, etc. */}

      {/* NEW: Entity section */}
      {atom.all_entities && atom.all_entities.length > 0 && (
        <div className="border-t pt-4">
          <h3 className="font-semibold mb-2">People & Entities</h3>

          <div className="space-y-2">
            {atom.all_entities.map((entity, i) => (
              <div key={i} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div className="flex items-center gap-2">
                  <EntityChip entity={entity} />

                  {/* Role badge */}
                  <Badge variant="outline" className="text-xs">
                    {entity.role === 'subject' && '🎤 Speaking'}
                    {entity.role === 'object' && '📝 Mentioned'}
                    {entity.role === 'visible' && '👁️ Visible'}
                  </Badge>
                </div>

                {/* Source indicator */}
                <div className="text-xs text-gray-500">
                  {entity.source === 'audio' ? '🎧 Audio' : '📹 Video'}
                </div>
              </div>
            ))}
          </div>

          {/* Visual entities detail */}
          {atom.visible_entities && atom.visible_entities.length > 0 && (
            <div className="mt-2 text-xs text-gray-500">
              <p>Face detection: {atom.visible_entities.length} {atom.visible_entities.length === 1 ? 'person' : 'people'} visible</p>
              {atom.visible_entities.map((ve, i) => (
                <p key={i}>
                  • {ve.entity_name}: {ve.appearance_count} frame{ve.appearance_count > 1 ? 's' : ''} ({(ve.confidence * 100).toFixed(0)}% confident)
                </p>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

### Atom List Item Enhancement

Show entity chips on atom cards in the search/browse view:

```tsx
// src/components/atoms/AtomListItem.tsx

export default function AtomListItem({ atom }: { atom: AtomWithEntities }) {
  return (
    <div className="p-4 border rounded hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="font-medium">{atom.action}</h3>
          <p className="text-sm text-gray-600 mt-1">
            {atom.transcript_excerpt}
          </p>

          {/* Entity chips */}
          {atom.all_entities && atom.all_entities.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-2">
              {atom.all_entities.map((entity, i) => (
                <EntityChip
                  key={i}
                  entity={entity}
                  size="sm"
                  badge={entity.source === 'visual' ? '📹' : undefined}
                />
              ))}
            </div>
          )}
        </div>

        <Badge className="ml-2">
          {atom.emotion}
        </Badge>
      </div>
    </div>
  );
}
```

## Step 6: Search Integration

### Search Query Enhancement

```typescript
// src/services/atomSearch.ts

interface AtomSearchFilters {
  query?: string;
  entities?: string[]; // Entity IDs to filter by
  entitySource?: 'audio' | 'visual' | 'any'; // NEW: Filter by entity source
  emotions?: string[];
  clips?: string[];
}

async function searchAtoms(filters: AtomSearchFilters) {
  const supabase = createClient(...);

  // Get all clips (we'll filter atoms client-side since they're in JSONB)
  let query = supabase
    .from('clips')
    .select('id, name, atoms_data, duration')
    .eq('status', 'ready');

  // If filtering by entities, first find clips with those entities
  if (filters.entities && filters.entities.length > 0) {
    const { data: clipsWithEntities } = await supabase
      .from('clip_entities')
      .select('clip_id')
      .in('entity_id', filters.entities);

    const clipIds = clipsWithEntities?.map(ce => ce.clip_id) || [];
    if (clipIds.length > 0) {
      query = query.in('id', clipIds);
    } else {
      return []; // No clips have these entities
    }
  }

  const { data: clips } = await query;

  // Filter atoms within clips
  const matchingAtoms = [];

  for (const clip of clips || []) {
    for (const atom of clip.atoms_data || []) {
      // Check entity filters
      if (filters.entities && filters.entities.length > 0) {
        const atomEntityIds = [
          atom.subject_entity_id,
          atom.object_entity_id,
          ...(atom.visible_entities?.map(ve => ve.entity_id) || [])
        ].filter(Boolean);

        const hasMatchingEntity = filters.entities.some(
          filterId => atomEntityIds.includes(filterId)
        );

        if (!hasMatchingEntity) continue;

        // Check entity source filter
        if (filters.entitySource) {
          if (filters.entitySource === 'audio') {
            const hasAudioEntity = filters.entities.some(
              filterId =>
                atom.subject_entity_id === filterId ||
                atom.object_entity_id === filterId
            );
            if (!hasAudioEntity) continue;
          } else if (filters.entitySource === 'visual') {
            const hasVisualEntity = atom.visible_entities?.some(
              ve => filters.entities.includes(ve.entity_id)
            );
            if (!hasVisualEntity) continue;
          }
        }
      }

      // Check other filters (emotion, text search, etc.)
      if (filters.emotions && !filters.emotions.includes(atom.emotion)) {
        continue;
      }

      if (filters.query) {
        const searchText = [
          atom.action,
          atom.transcript_excerpt,
          atom.subject_text,
          atom.object_text
        ].join(' ').toLowerCase();

        if (!searchText.includes(filters.query.toLowerCase())) {
          continue;
        }
      }

      matchingAtoms.push({
        ...atom,
        clip_id: clip.id,
        clip_name: clip.name
      });
    }
  }

  return matchingAtoms;
}
```

### Search UI Enhancement

```tsx
// src/components/search/SearchFilters.tsx

export default function SearchFilters({ filters, onChange }: SearchFiltersProps) {
  const [entities, setEntities] = useState<Entity[]>([]);
  const [entitySource, setEntitySource] = useState<'any' | 'audio' | 'visual'>('any');

  useEffect(() => {
    fetchEntities();
  }, []);

  async function fetchEntities() {
    const { data } = await supabase
      .from('entities')
      .select('*')
      .eq('type', 'PERSON')
      .order('name');

    if (data) setEntities(data);
  }

  return (
    <div className="space-y-4">
      {/* Text search */}
      <Input
        placeholder="Search atoms..."
        value={filters.query || ''}
        onChange={(e) => onChange({ ...filters, query: e.target.value })}
      />

      {/* Entity filter */}
      <div>
        <Label>Filter by Person</Label>
        <Select
          value={filters.entities?.[0] || ''}
          onValueChange={(value) => onChange({ ...filters, entities: value ? [value] : [] })}
        >
          <SelectTrigger>
            <SelectValue placeholder="All people" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">All people</SelectItem>
            {entities.map(entity => (
              <SelectItem key={entity.id} value={entity.id}>
                {entity.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Entity source filter (NEW) */}
      {filters.entities && filters.entities.length > 0 && (
        <div>
          <Label>Entity Source</Label>
          <RadioGroup value={entitySource} onValueChange={(v: any) => {
            setEntitySource(v);
            onChange({ ...filters, entitySource: v });
          }}>
            <div className="flex items-center space-x-2">
              <RadioGroupItem value="any" id="any" />
              <Label htmlFor="any">Any (audio or video)</Label>
            </div>
            <div className="flex items-center space-x-2">
              <RadioGroupItem value="audio" id="audio" />
              <Label htmlFor="audio">🎧 Audio only (mentioned in speech)</Label>
            </div>
            <div className="flex items-center space-x-2">
              <RadioGroupItem value="visual" id="visual" />
              <Label htmlFor="visual">📹 Video only (visible on screen)</Label>
            </div>
          </RadioGroup>
        </div>
      )}

      {/* Emotion filter */}
      <div>
        <Label>Filter by Emotion</Label>
        {/* ... emotion selection ... */}
      </div>
    </div>
  );
}
```

## Step 7: Auto-Labeling for New Videos

### Face Recognition Matching

When a new video is uploaded and face detection runs, automatically check if detected faces match existing labeled clusters:

```typescript
// Edge Function: cluster-faces (enhanced)

async function clusterAndMatchFaces(clipId: string) {
  const supabase = createClient(...);

  // 1. Get all face detections for this new clip
  const { data: newDetections } = await supabase
    .from('face_detections')
    .select('id, face_embedding, timestamp_seconds')
    .eq('clip_id', clipId)
    .is('face_cluster_id', null); // Not yet clustered

  // 2. Get all existing labeled face clusters
  const { data: existingClusters } = await supabase
    .from('face_clusters')
    .select(`
      id,
      entity_id,
      representative_detection_id,
      face_detections!representative_detection_id (face_embedding)
    `)
    .eq('is_labeled', true);

  // 3. For each new detection, find best matching cluster
  const MATCH_THRESHOLD = 0.65; // 65% similarity = same person
  const assignments: Map<string, string[]> = new Map(); // cluster_id -> detection_ids

  for (const detection of newDetections || []) {
    let bestMatch: { clusterId: string; similarity: number } | null = null;

    // Compare with each existing cluster's representative face
    for (const cluster of existingClusters || []) {
      if (!cluster.face_detections?.face_embedding) continue;

      const similarity = cosineSimilarity(
        detection.face_embedding,
        cluster.face_detections.face_embedding
      );

      if (similarity > MATCH_THRESHOLD && (!bestMatch || similarity > bestMatch.similarity)) {
        bestMatch = { clusterId: cluster.id, similarity };
      }
    }

    if (bestMatch) {
      // Matched existing labeled cluster - auto-assign
      if (!assignments.has(bestMatch.clusterId)) {
        assignments.set(bestMatch.clusterId, []);
      }
      assignments.get(bestMatch.clusterId)!.push(detection.id);

      console.log(`Auto-matched detection ${detection.id} to cluster ${bestMatch.clusterId} (${(bestMatch.similarity * 100).toFixed(1)}% similar)`);
    } else {
      // No match - create new unlabeled cluster
      const { data: newCluster } = await supabase
        .from('face_clusters')
        .insert({
          is_labeled: false,
          total_detections: 1,
          representative_detection_id: detection.id
        })
        .select()
        .single();

      if (newCluster) {
        await supabase
          .from('face_detections')
          .update({ face_cluster_id: newCluster.id })
          .eq('id', detection.id);
      }
    }
  }

  // 4. Batch update detections with cluster assignments
  for (const [clusterId, detectionIds] of assignments.entries()) {
    // Get entity_id from cluster
    const { data: cluster } = await supabase
      .from('face_clusters')
      .select('entity_id')
      .eq('id', clusterId)
      .single();

    // Update all detections in this cluster
    await supabase
      .from('face_detections')
      .update({
        face_cluster_id: clusterId,
        entity_id: cluster?.entity_id || null
      })
      .in('id', detectionIds);

    console.log(`Assigned ${detectionIds.length} detections to cluster ${clusterId} (entity: ${cluster?.entity_id})`);
  }

  // 5. Enrich atoms with face data (now that faces are labeled)
  await enrichAtomsWithFaces(clipId);

  // 6. Update clip entities
  await updateClipEntitiesFromFaces(clipId);

  return {
    totalDetections: newDetections?.length || 0,
    autoLabeled: Array.from(assignments.values()).flat().length,
    needsLabeling: (newDetections?.length || 0) - Array.from(assignments.values()).flat().length
  };
}
```

### Auto-Labeling Notification

```tsx
// src/components/faces/AutoLabelingBanner.tsx

interface AutoLabelingResult {
  clipId: string;
  totalDetections: number;
  autoLabeled: number;
  needsLabeling: number;
}

export default function AutoLabelingBanner({ result }: { result: AutoLabelingResult }) {
  if (result.autoLabeled === 0 && result.needsLabeling === 0) {
    return null;
  }

  return (
    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
      <div className="flex items-start gap-3">
        <div className="text-blue-600">
          <User className="w-5 h-5" />
        </div>

        <div className="flex-1">
          <h3 className="font-semibold text-blue-900">
            Face Detection Complete
          </h3>

          <div className="mt-2 space-y-1 text-sm">
            {result.autoLabeled > 0 && (
              <p className="text-blue-800">
                ✅ Automatically labeled {result.autoLabeled} {result.autoLabeled === 1 ? 'face' : 'faces'} from previous videos
              </p>
            )}

            {result.needsLabeling > 0 && (
              <p className="text-blue-800">
                ❓ {result.needsLabeling} new {result.needsLabeling === 1 ? 'face needs' : 'faces need'} labeling
              </p>
            )}
          </div>

          {result.needsLabeling > 0 && (
            <Button
              size="sm"
              className="mt-3"
              onClick={() => {
                // Open face labeling modal
                openFaceLabelingModal(result.clipId);
              }}
            >
              Label New Faces
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
```

## Database Trigger for Automatic Propagation

To ensure atom enrichment happens automatically when faces are labeled:

```sql
-- Trigger function to enrich atoms after face labeling
CREATE OR REPLACE FUNCTION enrich_atoms_on_face_label()
RETURNS TRIGGER AS $$
BEGIN
  -- Queue atom enrichment job when face_cluster gets labeled
  IF (NEW.is_labeled = true AND OLD.is_labeled = false) THEN
    -- Find all clips that have faces from this cluster
    PERFORM enrich_atoms_for_cluster(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to face_clusters table
CREATE TRIGGER face_cluster_labeled
AFTER UPDATE ON face_clusters
FOR EACH ROW
WHEN (NEW.is_labeled IS DISTINCT FROM OLD.is_labeled)
EXECUTE FUNCTION enrich_atoms_on_face_label();

-- Function to enrich all clips with faces from a cluster
CREATE OR REPLACE FUNCTION enrich_atoms_for_cluster(cluster_uuid UUID)
RETURNS void AS $$
DECLARE
  affected_clip_id UUID;
BEGIN
  -- Get all clips with faces from this cluster
  FOR affected_clip_id IN
    SELECT DISTINCT clip_id
    FROM face_detections
    WHERE face_cluster_id = cluster_uuid
  LOOP
    -- Call Edge Function to enrich atoms
    -- In practice, this would be a pg_net HTTP request to Edge Function
    PERFORM net.http_post(
      url := current_setting('app.edge_function_url') || '/enrich-atoms-with-faces',
      body := json_build_object('clipId', affected_clip_id)::text
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## Post-Processing Existing Videos

For videos that were processed before face detection was enabled:

```typescript
// Admin script: backfill-face-detection.ts

async function backfillFaceDetection() {
  const supabase = createClient(...);

  // Get all clips that don't have face_coordinates
  const { data: clips } = await supabase
    .from('clips')
    .select('id, proxy_url')
    .eq('status', 'ready')
    .is('face_coordinates', null);

  console.log(`Found ${clips?.length || 0} clips to process`);

  for (const clip of clips || []) {
    console.log(`Processing clip ${clip.id}...`);

    try {
      // 1. Run face detection
      await fetch(`${EDGE_FUNCTION_URL}/detect-faces`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clipId: clip.id,
          videoUrl: clip.proxy_url
        })
      });

      // 2. Cluster faces (will auto-match to existing clusters)
      const result = await fetch(`${EDGE_FUNCTION_URL}/cluster-faces`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clipId: clip.id })
      }).then(r => r.json());

      console.log(`  ✓ Detected ${result.totalDetections} faces`);
      console.log(`  ✓ Auto-labeled ${result.autoLabeled} faces`);
      console.log(`  ⚠ ${result.needsLabeling} faces need manual labeling`);

      // Rate limit to avoid overwhelming system
      await new Promise(resolve => setTimeout(resolve, 5000));

    } catch (error) {
      console.error(`  ✗ Failed to process clip ${clip.id}:`, error);
    }
  }

  console.log('Backfill complete!');
}

// Run backfill
backfillFaceDetection();
```

## Summary: Complete Data Flow

1. **Video Upload** → Face detection runs automatically
2. **Face Clustering** → Groups unique individuals, checks for matches with existing labeled clusters
3. **Auto-Labeling** → Recognized faces automatically get entity_id assigned
4. **User Labeling** → New faces presented to user for manual labeling
5. **Atom Enrichment** → Edge Function matches face timestamps to atom time ranges
6. **Atom Update** → `atoms_data` JSONB enriched with `visible_entities` array
7. **Clip Aggregation** → `clip_entities` table updated with all entities (audio + visual)
8. **Editor UI Display** → Atoms show person chips with audio/visual source indicators
9. **Search Integration** → Users can filter atoms by person, with option to filter by source
10. **Future Videos** → New uploads automatically recognize previously labeled people

## Key Benefits

- **Automatic Propagation:** Face labels automatically flow through to atoms without manual work
- **Bi-directional Search:** Find clips by person, or see all people in a clip
- **Audio-Visual Fusion:** Atoms show both who is speaking and who is visible
- **Future-Proof:** New videos automatically benefit from existing face labels
- **Post-Processing:** Existing video libraries can be retroactively enriched with face data
