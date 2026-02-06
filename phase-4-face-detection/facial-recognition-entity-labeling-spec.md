# Facial Recognition & Entity Labeling System Specification

## Executive Summary

This document specifies a facial recognition system for Creative Edit Suite (Lovable) that goes beyond the original project's basic face detection. The system will:

1. **Detect unique individuals** in video clips using facial recognition
2. **Track face appearances** across clips with timestamps and bounding boxes
3. **Present unlabeled faces** to users via an intuitive labeling UI
4. **Link labeled faces to entity records** in the knowledge graph
5. **Enable face-based search** and entity discovery

This is particularly valuable for:
- **Single-user interview scenarios** where guests appear on camera but aren't named in audio
- **Consumer applications** where users want to catalog who appears in their video library
- **Podcasts and panel discussions** where multiple people appear on screen
- **Content creators** building searchable archives of their shows

## System Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│ 1. Video Upload & Processing                       │
│    ↓                                                │
│ 2. Face Detection (Extract frames → Detect faces)  │
│    ↓                                                │
│ 3. Face Recognition (Group unique individuals)     │
│    ↓                                                │
│ 4. Face Database Storage (face_detections table)   │
│    ↓                                                │
│ 5. User Labeling UI (Present unlabeled faces)      │
│    ↓                                                │
│ 6. Entity Linking (Connect face_id → entity_id)    │
│    ↓                                                │
│ 7. Enhanced Search (Find clips by person)          │
└─────────────────────────────────────────────────────┘
```

## Current State Analysis

### Original Project (yt-claude-code)
- **Has:** Basic face detection for intelligent video cropping (16:9 to 9:16)
- **Uses:** FFmpeg cropdetect filter to find "active regions"
- **Missing:** Facial recognition, person identification, entity linking
- **Purpose:** Face-aware reframing, not person identification

### Lovable Project (creative-edit-suite)
- **Has:** `face_coordinates` JSONB field in clips table (currently unused)
- **Missing:** Face detection implementation, facial recognition, labeling UI
- **Opportunity:** Build complete facial recognition + entity system from scratch

## Database Schema Design

### New Tables

#### 1. face_detections Table

Stores individual face detections with embeddings for recognition.

```sql
CREATE TABLE face_detections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Clip association
    clip_id UUID REFERENCES clips(id) ON DELETE CASCADE NOT NULL,

    -- Temporal location
    timestamp_seconds FLOAT NOT NULL, -- When face appears in video

    -- Spatial location (normalized 0-1)
    bbox_x FLOAT NOT NULL CHECK (bbox_x >= 0 AND bbox_x <= 1),
    bbox_y FLOAT NOT NULL CHECK (bbox_y >= 0 AND bbox_y <= 1),
    bbox_width FLOAT NOT NULL CHECK (bbox_width >= 0 AND bbox_width <= 1),
    bbox_height FLOAT NOT NULL CHECK (bbox_height >= 0 AND bbox_height <= 1),

    -- Face embedding for recognition (128 or 512 dimensions)
    -- Using 512d for better accuracy (e.g., InsightFace ArcFace model)
    face_embedding vector(512),

    -- Quality metrics
    confidence FLOAT DEFAULT 1.0 CHECK (confidence >= 0 AND confidence <= 1),
    face_size INTEGER, -- Size in pixels (larger = better quality)
    blur_score FLOAT, -- Laplacian variance (higher = sharper)

    -- Recognition grouping
    face_cluster_id UUID, -- Unique ID for this person (before labeling)
    entity_id UUID REFERENCES entities(id) ON DELETE SET NULL, -- After user labels

    -- Visual snapshot
    thumbnail_path TEXT, -- Cropped face thumbnail for UI display

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indices for performance
    INDEX idx_face_detections_clip ON face_detections(clip_id),
    INDEX idx_face_detections_cluster ON face_detections(face_cluster_id),
    INDEX idx_face_detections_entity ON face_detections(entity_id),
    INDEX idx_face_detections_embedding ON face_detections
        USING ivfflat (face_embedding vector_cosine_ops) WITH (lists = 100)
);

COMMENT ON TABLE face_detections IS 'Individual face detections in clips with embeddings for recognition';
COMMENT ON COLUMN face_detections.face_embedding IS 'Face embedding vector (512d) for facial recognition via cosine similarity';
COMMENT ON COLUMN face_detections.face_cluster_id IS 'Unique ID grouping detections of same person (before user labeling)';
COMMENT ON COLUMN face_detections.entity_id IS 'Links to entities table after user labels this face';
```

#### 2. face_clusters Table

Tracks unique individuals across all clips (before and after labeling).

```sql
CREATE TABLE face_clusters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Representative face (best quality detection from this person)
    representative_detection_id UUID REFERENCES face_detections(id) ON DELETE SET NULL,

    -- Entity linkage
    entity_id UUID REFERENCES entities(id) ON DELETE SET NULL,
    is_labeled BOOLEAN DEFAULT false,
    labeled_by_user BOOLEAN DEFAULT false, -- true if user labeled, false if auto-matched

    -- Statistics
    total_detections INTEGER DEFAULT 0,
    avg_confidence FLOAT,
    first_seen_clip_id UUID REFERENCES clips(id) ON DELETE SET NULL,
    last_seen_clip_id UUID REFERENCES clips(id) ON DELETE SET NULL,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    INDEX idx_face_clusters_entity ON face_clusters(entity_id),
    INDEX idx_face_clusters_labeled ON face_clusters(is_labeled)
);

COMMENT ON TABLE face_clusters IS 'Groups face detections by unique individual across all clips';
COMMENT ON COLUMN face_clusters.representative_detection_id IS 'Best quality face detection for thumbnail/preview';
```

### Enhanced Existing Tables

#### clips.face_coordinates Enhancement

The existing `face_coordinates` JSONB field should store aggregated face data:

```typescript
interface FaceCoordinates {
  cluster_id: string;        // UUID of face_cluster
  entity_id?: string;        // UUID if labeled
  entity_name?: string;      // Name for quick display
  appearances: Array<{
    timestamp: number;       // seconds
    bbox: {                  // normalized 0-1
      x: number;
      y: number;
      width: number;
      height: number;
    };
    confidence: number;
  }>;
  total_screen_time: number; // seconds this person is on screen
  avg_confidence: number;
}

// Example:
{
  "cluster_id": "abc-123",
  "entity_id": "def-456",
  "entity_name": "Kara Smith",
  "appearances": [
    {
      "timestamp": 12.5,
      "bbox": { "x": 0.3, "y": 0.1, "width": 0.2, "height": 0.3 },
      "confidence": 0.95
    }
  ],
  "total_screen_time": 45.2,
  "avg_confidence": 0.92
}
```

## Facial Recognition Pipeline

### Step 1: Face Detection

**Technology Options:**

1. **MediaPipe Face Detection (Recommended for Lovable)**
   - Pros: Free, runs in browser (no server costs), real-time
   - Cons: Less accurate than server-based models
   - Use case: Client-side detection for immediate feedback

2. **InsightFace ArcFace (Recommended for accuracy)**
   - Pros: State-of-art accuracy, 512d embeddings
   - Cons: Requires Python backend or Edge Function with model
   - Use case: Server-side processing for high-quality recognition

3. **AWS Rekognition**
   - Pros: Fully managed, excellent accuracy, handles at scale
   - Cons: Costs per image analyzed (~$0.001/image)
   - Use case: Production deployment with budget

**Recommended Approach for Lovable:**

Hybrid system:
- **Initial detection:** MediaPipe in browser for fast preview
- **Final recognition:** InsightFace via Supabase Edge Function for accurate clustering

### Step 2: Face Extraction & Embedding Generation

```typescript
// Edge Function: detect-faces

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Face detection model (loaded once per function instance)
let faceModel: any = null;

async function loadFaceModel() {
  if (faceModel) return faceModel;

  // Load InsightFace ArcFace model
  // In production, this would be a TensorFlow.js or ONNX model
  // For now, placeholder
  faceModel = {}; // TODO: Load actual model
  return faceModel;
}

serve(async (req) => {
  const { clipId, videoUrl } = await req.json();

  // 1. Download video from Supabase Storage
  const videoPath = await downloadVideo(videoUrl);

  // 2. Extract frames at intervals (every 1 second)
  const frames = await extractFrames(videoPath, { interval: 1 });

  // 3. Detect faces in each frame
  const model = await loadFaceModel();
  const detections: FaceDetection[] = [];

  for (const frame of frames) {
    const faces = await detectFacesInFrame(model, frame);

    for (const face of faces) {
      // Generate 512d embedding
      const embedding = await generateFaceEmbedding(model, frame, face.bbox);

      detections.push({
        clip_id: clipId,
        timestamp_seconds: frame.timestamp,
        bbox_x: face.bbox.x,
        bbox_y: face.bbox.y,
        bbox_width: face.bbox.width,
        bbox_height: face.bbox.height,
        face_embedding: embedding,
        confidence: face.confidence,
        face_size: face.width * face.height,
        blur_score: calculateBlurScore(frame, face.bbox)
      });
    }
  }

  // 4. Store detections in database
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await supabase.from('face_detections').insert(detections);

  return new Response(
    JSON.stringify({ success: true, count: detections.length }),
    { headers: { 'Content-Type': 'application/json' } }
  );
});
```

### Step 3: Face Clustering (Grouping Unique Individuals)

```typescript
// Edge Function: cluster-faces

// Uses DBSCAN or hierarchical clustering on face embeddings
// Groups detections of same person together

async function clusterFaceDetections(clipId: string) {
  const supabase = createClient(...);

  // Fetch all detections for this clip
  const { data: detections } = await supabase
    .from('face_detections')
    .select('id, face_embedding, confidence')
    .eq('clip_id', clipId);

  // Cluster by embedding similarity
  const clusters = clusterByCosineSimilarity(
    detections,
    threshold: 0.6 // Faces with >0.6 similarity = same person
  );

  // Create or update face_clusters
  for (const cluster of clusters) {
    // Check if this face matches existing clusters
    const matchingCluster = await findMatchingCluster(cluster.centroid);

    if (matchingCluster) {
      // Update existing cluster
      await supabase
        .from('face_detections')
        .update({ face_cluster_id: matchingCluster.id })
        .in('id', cluster.detection_ids);
    } else {
      // Create new cluster
      const { data: newCluster } = await supabase
        .from('face_clusters')
        .insert({
          total_detections: cluster.detection_ids.length,
          avg_confidence: cluster.avg_confidence
        })
        .select()
        .single();

      await supabase
        .from('face_detections')
        .update({ face_cluster_id: newCluster.id })
        .in('id', cluster.detection_ids);
    }
  }

  // Update clips.face_coordinates JSONB
  await updateClipFaceCoordinates(clipId);
}

// Find if this face matches existing clusters across all clips
async function findMatchingCluster(
  embedding: number[],
  threshold: number = 0.6
): Promise<FaceCluster | null> {
  const supabase = createClient(...);

  // Get representative faces from all existing clusters
  const { data: clusters } = await supabase
    .from('face_clusters')
    .select(`
      id,
      face_detections!representative_detection_id (face_embedding)
    `);

  // Calculate cosine similarity with each cluster's representative
  for (const cluster of clusters) {
    const similarity = cosineSimilarity(
      embedding,
      cluster.face_detections.face_embedding
    );

    if (similarity > threshold) {
      return cluster;
    }
  }

  return null;
}
```

## User Labeling Interface

### 1. Face Labeling Modal

Presented after video processing completes.

```
┌─────────────────────────────────────────────────────┐
│ Label Detected Faces                         [X]    │
├─────────────────────────────────────────────────────┤
│                                                     │
│ We detected 3 unique people in this clip.          │
│ Help us identify them:                             │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐         │
│  │  [Face Photo]   │  │  [Face Photo]   │  ...    │
│  │                 │  │                 │         │
│  │ Person 1        │  │ Person 2        │         │
│  │ 45 appearances  │  │ 23 appearances  │         │
│  │                 │  │                 │         │
│  │ [Select Entity] │  │ [Select Entity] │         │
│  │ or              │  │ or              │         │
│  │ [Create New]    │  │ [Create New]    │         │
│  │ [Skip]          │  │ [Skip]          │         │
│  └─────────────────┘  └─────────────────┘         │
│                                                     │
│  [Skip All]                  [Save Labels]         │
└─────────────────────────────────────────────────────┘
```

#### Component Structure

```tsx
// src/components/faces/FaceLabelingModal.tsx

import { useState, useEffect } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { supabase } from '@/lib/supabase';
import CreateEntityModal from '@/components/entities/CreateEntityModal';

interface UnlabeledFaceCluster {
  id: string;
  thumbnail_url: string;
  total_detections: number;
  avg_confidence: number;
  sample_timestamps: number[]; // Show when this person appears
}

interface FaceLabelingModalProps {
  clipId: string;
  open: boolean;
  onClose: () => void;
  onComplete: () => void;
}

export default function FaceLabelingModal({
  clipId,
  open,
  onClose,
  onComplete
}: FaceLabelingModalProps) {
  const [unlabeledFaces, setUnlabeledFaces] = useState<UnlabeledFaceCluster[]>([]);
  const [entities, setEntities] = useState<Entity[]>([]);
  const [selectedEntities, setSelectedEntities] = useState<Map<string, string>>(new Map());
  const [isCreateEntityOpen, setIsCreateEntityOpen] = useState(false);
  const [currentCluster, setCurrentCluster] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      fetchUnlabeledFaces();
      fetchEntities();
    }
  }, [open, clipId]);

  async function fetchUnlabeledFaces() {
    // Get face clusters from this clip that aren't labeled yet
    const { data } = await supabase
      .from('face_clusters')
      .select(`
        id,
        total_detections,
        avg_confidence,
        representative_detection_id,
        face_detections!representative_detection_id (
          thumbnail_path
        )
      `)
      .eq('is_labeled', false)
      .in('id', (
        // Get cluster IDs that appear in this clip
        await supabase
          .from('face_detections')
          .select('face_cluster_id')
          .eq('clip_id', clipId)
      ).data?.map(d => d.face_cluster_id) || []);

    if (data) {
      setUnlabeledFaces(data.map(cluster => ({
        id: cluster.id,
        thumbnail_url: cluster.face_detections.thumbnail_path,
        total_detections: cluster.total_detections,
        avg_confidence: cluster.avg_confidence,
        sample_timestamps: [] // TODO: fetch timestamps
      })));
    }
  }

  async function fetchEntities() {
    const { data } = await supabase
      .from('entities')
      .select('*')
      .eq('type', 'PERSON')
      .order('name');

    if (data) setEntities(data);
  }

  async function handleSave() {
    // Link selected face clusters to entities
    for (const [clusterId, entityId] of selectedEntities.entries()) {
      // Update face_cluster
      await supabase
        .from('face_clusters')
        .update({
          entity_id: entityId,
          is_labeled: true,
          labeled_by_user: true
        })
        .eq('id', clusterId);

      // Update all face_detections in this cluster
      await supabase
        .from('face_detections')
        .update({ entity_id: entityId })
        .eq('face_cluster_id', clusterId);
    }

    // Update clip_entities for this clip
    await updateClipEntitiesFromFaces(clipId);

    onComplete();
    onClose();
  }

  function handleCreateEntity(clusterId: string) {
    setCurrentCluster(clusterId);
    setIsCreateEntityOpen(true);
  }

  function handleEntityCreated(newEntity: Entity) {
    setEntities([...entities, newEntity]);
    if (currentCluster) {
      setSelectedEntities(new Map(selectedEntities.set(currentCluster, newEntity.id)));
    }
    setIsCreateEntityOpen(false);
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onClose}>
        <DialogContent className="max-w-4xl">
          <DialogHeader>
            <DialogTitle>Label Detected Faces</DialogTitle>
          </DialogHeader>

          <div className="space-y-4">
            <p className="text-sm text-gray-600">
              We detected {unlabeledFaces.length} unique {unlabeledFaces.length === 1 ? 'person' : 'people'} in this clip.
              Help us identify them:
            </p>

            <div className="grid grid-cols-3 gap-4">
              {unlabeledFaces.map((face) => (
                <div key={face.id} className="border rounded-lg p-4 space-y-3">
                  <img
                    src={face.thumbnail_url}
                    alt="Face"
                    className="w-full h-32 object-cover rounded"
                  />

                  <div className="text-sm space-y-1">
                    <div className="font-medium">Person {unlabeledFaces.indexOf(face) + 1}</div>
                    <div className="text-gray-500">
                      {face.total_detections} {face.total_detections === 1 ? 'appearance' : 'appearances'}
                    </div>
                  </div>

                  <Select
                    value={selectedEntities.get(face.id) || ''}
                    onValueChange={(value) => {
                      setSelectedEntities(new Map(selectedEntities.set(face.id, value)));
                    }}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select person" />
                    </SelectTrigger>
                    <SelectContent>
                      {entities.map(entity => (
                        <SelectItem key={entity.id} value={entity.id}>
                          {entity.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>

                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      className="flex-1"
                      onClick={() => handleCreateEntity(face.id)}
                    >
                      Create New
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        // Skip this face
                        const newMap = new Map(selectedEntities);
                        newMap.delete(face.id);
                        setSelectedEntities(newMap);
                      }}
                    >
                      Skip
                    </Button>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex justify-end gap-2 pt-4">
              <Button variant="outline" onClick={onClose}>
                Skip All
              </Button>
              <Button
                onClick={handleSave}
                disabled={selectedEntities.size === 0}
              >
                Save Labels ({selectedEntities.size})
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      <CreateEntityModal
        open={isCreateEntityOpen}
        onClose={() => setIsCreateEntityOpen(false)}
        onEntityCreated={handleEntityCreated}
        defaultType="PERSON"
      />
    </>
  );
}
```

### 2. Face Timeline Component

Shows when each person appears in a clip.

```tsx
// src/components/faces/FaceTimeline.tsx

interface FaceTimelineProps {
  clipId: string;
  duration: number; // clip duration in seconds
}

export default function FaceTimeline({ clipId, duration }: FaceTimelineProps) {
  const [faceAppearances, setFaceAppearances] = useState<FaceAppearance[]>([]);

  useEffect(() => {
    fetchFaceAppearances();
  }, [clipId]);

  async function fetchFaceAppearances() {
    const { data } = await supabase
      .from('face_detections')
      .select(`
        timestamp_seconds,
        face_cluster_id,
        entity_id,
        entities (name)
      `)
      .eq('clip_id', clipId)
      .order('timestamp_seconds');

    if (data) {
      // Group by entity and show appearance ranges
      setFaceAppearances(data);
    }
  }

  return (
    <div className="space-y-2">
      <h3 className="font-semibold">People in this clip</h3>

      {/* Visual timeline */}
      <div className="relative h-12 bg-gray-100 rounded">
        {faceAppearances.map((appearance, i) => {
          const left = (appearance.timestamp_seconds / duration) * 100;
          return (
            <div
              key={i}
              className="absolute top-0 bottom-0 w-1 bg-blue-500"
              style={{ left: `${left}%` }}
              title={`${appearance.entities?.name || 'Unknown'} at ${appearance.timestamp_seconds}s`}
            />
          );
        })}
      </div>

      {/* Legend */}
      <div className="flex flex-wrap gap-2">
        {Array.from(new Set(faceAppearances.map(f => f.entity_id))).map(entityId => {
          const appearances = faceAppearances.filter(f => f.entity_id === entityId);
          const entityName = appearances[0]?.entities?.name || 'Unknown Person';

          return (
            <EntityChip
              key={entityId}
              entity={{ id: entityId, name: entityName, type: 'PERSON' }}
              count={appearances.length}
            />
          );
        })}
      </div>
    </div>
  );
}
```

## Search Enhancements

### Face-Based Search

```typescript
// Add to search interface

interface SearchFilters {
  query: string;
  entities: string[]; // Entity IDs
  hasFaces: boolean;  // NEW: Only show clips with detected faces
  faceCount?: { min: number; max: number }; // NEW: Filter by number of people
}

// Search query enhancement
async function searchClipsWithFaces(filters: SearchFilters) {
  let query = supabase
    .from('clips')
    .select(`
      *,
      face_coordinates,
      entities!clip_entities (id, name, type)
    `);

  if (filters.hasFaces) {
    // Only clips with face detections
    query = query.not('face_coordinates', 'is', null);
  }

  if (filters.entities.length > 0) {
    // Filter by specific people
    query = query.overlaps('face_coordinates', [
      { entity_id: filters.entities }
    ]);
  }

  return query;
}
```

## Implementation Phases

### Phase 1: Core Face Detection (Week 1-2)
- Database migration (face_detections, face_clusters tables)
- Edge Function for face detection using MediaPipe or InsightFace
- Frame extraction and face bounding box detection
- Store detections in database

### Phase 2: Face Recognition & Clustering (Week 3)
- Face embedding generation (512d vectors)
- Clustering algorithm (DBSCAN or hierarchical)
- Automatic matching across clips
- Representative face selection for thumbnails

### Phase 3: User Labeling UI (Week 4)
- Face labeling modal component
- Entity selection/creation workflow
- Face timeline visualization
- Clip entity updates after labeling

### Phase 4: Search & Discovery (Week 5)
- Face-based search filters
- Entity autocomplete with face counts
- "Find similar faces" feature
- Face gallery view (all appearances of a person)

## Technology Stack Recommendations

### Face Detection Options

1. **MediaPipe Face Detection**
   - **Pros:** Free, browser-based, real-time
   - **Cons:** Less accurate than server models
   - **Best for:** Consumer applications, immediate feedback

2. **InsightFace (ArcFace)**
   - **Pros:** SOTA accuracy, 512d embeddings
   - **Cons:** Requires Python/ONNX runtime
   - **Best for:** High-accuracy requirements

3. **face-api.js**
   - **Pros:** Pure JavaScript, runs in browser/Node
   - **Cons:** Lower accuracy than InsightFace
   - **Best for:** Quick prototyping, low-cost deployment

**Recommended for Lovable:** Start with face-api.js in Edge Functions, upgrade to InsightFace if accuracy isn't sufficient.

### Deployment Architecture

```
┌───────────────────────────────────────────┐
│ Client (Browser)                          │
│  - Upload video                           │
│  - View labeling UI                       │
│  - Search by face                         │
└─────────────┬─────────────────────────────┘
              │
              ↓
┌───────────────────────────────────────────┐
│ Supabase Edge Functions                  │
│  - detect-faces                           │
│  - cluster-faces                          │
│  - match-face-to-entity                   │
└─────────────┬─────────────────────────────┘
              │
              ↓
┌───────────────────────────────────────────┐
│ Supabase Database                         │
│  - face_detections                        │
│  - face_clusters                          │
│  - entities                               │
└───────────────────────────────────────────┘
```

## Privacy & Ethics Considerations

### User Consent
- **Explicit opt-in** for face detection processing
- **Clear disclosure** that facial recognition is being used
- **Data retention policy**: Option to delete face data

### Data Security
- Face embeddings are **one-way hashes** (cannot reconstruct face from embedding)
- Thumbnail images stored securely in Supabase Storage with RLS policies
- Entity names are user-provided, not automatically inferred

### Bias Mitigation
- Test face detection accuracy across diverse demographics
- Provide manual override if automated clustering is wrong
- Allow users to merge/split face clusters

## Success Metrics

- **Detection accuracy:** 95%+ faces detected in frames where people appear
- **Recognition accuracy:** 90%+ same-person detections correctly clustered
- **Labeling completion:** 70%+ of detected faces get labeled by users
- **Search effectiveness:** Face-based searches return relevant clips 95%+ of time
- **Performance:** Face detection adds <30 seconds per minute of video

## Future Enhancements

1. **Automatic entity creation:** Suggest creating new entities for frequently appearing unlabeled faces
2. **Face search:** "Find clips with people similar to this photo" (upload photo → find matches)
3. **Multi-face tracking:** Track interactions between people (who talks to whom)
4. **Emotion recognition:** Detect facial expressions (happy, sad, surprised)
5. **Age/gender estimation:** Demographic metadata for content cataloging
6. **Face blur/anonymization:** Automatically blur certain faces for privacy

## Migration Path for Existing Clips

```typescript
// Background job to process existing clips
async function processExistingClipsForFaces() {
  const { data: clips } = await supabase
    .from('clips')
    .select('id, proxy_url')
    .eq('status', 'ready')
    .is('face_coordinates', null); // Not yet processed

  for (const clip of clips) {
    console.log(`Processing clip ${clip.id} for faces`);

    // Trigger face detection
    await fetch('/api/detect-faces', {
      method: 'POST',
      body: JSON.stringify({
        clipId: clip.id,
        videoUrl: clip.proxy_url
      })
    });

    // Rate limit
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
}
```

## Conclusion

This facial recognition + entity labeling system transforms Creative Edit Suite from a clip-based editor into an intelligent content archive that understands **who** appears in videos, not just **what** is said. By automatically detecting faces, clustering unique individuals, and enabling user labeling, the system becomes invaluable for:

- **Content creators** building searchable show archives
- **Interviewers** cataloging guest appearances
- **Podcasters** tracking panel discussions
- **Educators** organizing lecture footage
- **Anyone** who wants to find "that clip where person X did Y"

The phased implementation ensures incremental value delivery while the system architecture allows for future enhancements like emotion recognition and face-based recommendations.
