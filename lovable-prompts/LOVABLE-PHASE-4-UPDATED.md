# Phase 4: Face Detection & Clustering - Lovable Implementation Prompt

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 4 of 7
**Duration:** 2-3 weeks
**Priority:** HIGH
**Depends On:** Phase 1 (Database Schema)

---

## 🎯 Objective

Implement face detection, embedding generation, and clustering to identify unique individuals in video clips. This phase builds the computer vision infrastructure that Phase 5 (Face Labeling UI) will use to connect faces to entities.

**What this phase delivers:**
- Automatic face detection from video frames
- 512-dimensional face embeddings for recognition
- DBSCAN clustering to group faces by unique individual
- Cross-clip face matching (same person across multiple videos)
- Foundation for user labeling in Phase 5

---

## 📋 Prerequisites

Before starting Phase 4, ensure:

- ✅ Phase 1 database schema is deployed (face_detections and face_clusters tables exist)
- ✅ Existing video processing pipeline works (process-video → analyze-atoms)
- ✅ Supabase Edge Functions environment is set up
- ✅ pgvector extension is enabled in Supabase

---

## 🏗️ Implementation Overview

Phase 4 adds three new Edge Functions that run sequentially after `analyze-atoms`:

```
process-video (existing)
    ↓
analyze-atoms (existing - Phase 3)
    ↓
face-detect (NEW) ← Detects faces in frames
    ↓
face-embed (NEW) ← Generates embeddings
    ↓
face-cluster (NEW) ← Groups by unique individual
    ↓
Mark clip as "ready"
```

---

## 🔧 Edge Function 1: face-detect

### Purpose
Extract frames from video and detect all faces with bounding boxes.

### Technology
**face-api.js** - JavaScript face detection library compatible with Deno

### Installation
```bash
# In your Edge Functions directory
npm install face-api.js
```

### File Location
`supabase/functions/face-detect/index.ts`

### Input
```typescript
{
  clipId: string;      // UUID of clip to process
  videoUrl: string;    // Supabase Storage URL
}
```

### Processing Steps

1. **Load Models** (once per function instance, cache in memory):
```typescript
import * as faceapi from 'face-api.js';

// Load detection and landmark models
await faceapi.nets.ssdMobilenetv1.loadFromUri('/path/to/models');
await faceapi.nets.faceLandmark68Net.loadFromUri('/path/to/models');
```

2. **Download Video**:
```typescript
const videoPath = await downloadFromSupabase(videoUrl);
```

3. **Extract Frames** at 1 FPS using FFmpeg:
```bash
ffmpeg -i input.mp4 -vf fps=1 frame_%04d.jpg
```

4. **Detect Faces** in each frame:
```typescript
for (const frame of frames) {
  const detections = await faceapi
    .detectAllFaces(frame)
    .withFaceLandmarks();

  for (const detection of detections) {
    // Normalize coordinates to 0-1 range
    const bbox = {
      x: detection.box.x / frameWidth,
      y: detection.box.y / frameHeight,
      width: detection.box.width / frameWidth,
      height: detection.box.height / frameHeight,
    };

    await supabase.from('face_detections').insert({
      clip_id: clipId,
      timestamp_seconds: frame.timestamp,
      bbox_x: bbox.x,
      bbox_y: bbox.y,
      bbox_width: bbox.width,
      bbox_height: bbox.height,
      confidence: detection.score,
      face_embedding: null, // Will be populated by face-embed
    });
  }
}
```

### Output
Records in `face_detections` table with bounding box coordinates (no embeddings yet).

### Error Handling
- If no faces detected: Success (return empty array)
- If video download fails: Retry once, then error
- If FFmpeg fails: Error (log details)

---

## 🔧 Edge Function 2: face-embed

### Purpose
Generate 512-dimensional face embeddings for facial recognition.

### Technology
**face-api.js** with faceRecognitionNet model (produces 128d descriptors)

### File Location
`supabase/functions/face-embed/index.ts`

### Input
```typescript
{
  clipId: string;  // Process all face_detections for this clip
}
```

### Processing Steps

1. **Load Recognition Model**:
```typescript
await faceapi.nets.faceRecognitionNet.loadFromUri('/path/to/models');
```

2. **Fetch Detections Without Embeddings**:
```typescript
const { data: detections } = await supabase
  .from('face_detections')
  .select('*')
  .eq('clip_id', clipId)
  .is('face_embedding', null);
```

3. **Generate Embeddings** for each face:
```typescript
for (const detection of detections) {
  // Extract face region from frame
  const faceImage = await cropFaceFromFrame(
    detection.timestamp_seconds,
    detection.bbox_x,
    detection.bbox_y,
    detection.bbox_width,
    detection.bbox_height
  );

  // Generate 128d descriptor
  const descriptor = await faceapi
    .computeFaceDescriptor(faceImage);

  // Normalize to unit length
  const normalized = normalizeVector(descriptor);

  // Update database
  await supabase
    .from('face_detections')
    .update({ face_embedding: normalized })
    .eq('id', detection.id);
}
```

### Output
Updated `face_detections` records with `face_embedding` vectors.

---

## 🔧 Edge Function 3: face-cluster

### Purpose
Group face embeddings by unique individual using DBSCAN clustering.

### Technology
- **DBSCAN algorithm** for clustering
- **Cosine similarity** for face matching
- **pgvector** for efficient similarity search

### File Location
`supabase/functions/face-cluster/index.ts`

### Input
```typescript
{
  clipId: string;  // Cluster faces in this clip
}
```

### Processing Steps

1. **Fetch Face Embeddings**:
```typescript
const { data: faces } = await supabase
  .from('face_detections')
  .select('id, face_embedding, confidence, timestamp_seconds')
  .eq('clip_id', clipId)
  .not('face_embedding', 'is', null);
```

2. **Run DBSCAN Clustering**:
```typescript
// Parameters
const EPS = 0.35;        // Max distance for same cluster
const MIN_SAMPLES = 2;   // Min faces to form cluster

// Distance function: 1 - cosine similarity
const distanceFn = (a, b) => 1 - cosineSimilarity(a, b);

const clusters = dbscan(faces, {
  eps: EPS,
  minSamples: MIN_SAMPLES,
  distanceFunction: distanceFn
});
```

3. **Match Against Existing Clusters** (cross-clip recognition):
```typescript
for (const cluster of clusters) {
  // Calculate cluster centroid (average embedding)
  const centroid = calculateCentroid(cluster.faces);

  // Find existing cluster with similar centroid
  const { data: matchingCluster } = await supabase.rpc(
    'find_similar_cluster',
    {
      query_embedding: centroid,
      similarity_threshold: 0.6
    }
  );

  if (matchingCluster) {
    // Use existing cluster
    clusterIdToUse = matchingCluster.id;
  } else {
    // Create new cluster
    const { data: newCluster } = await supabase
      .from('face_clusters')
      .insert({
        cluster_key: `cluster-${uuidv4()}`,
        status: 'unlabeled',
        total_detections: cluster.faces.length,
      })
      .select('id')
      .single();

    clusterIdToUse = newCluster.id;
  }

  // Link all faces to cluster
  await supabase
    .from('face_detections')
    .update({ face_cluster_id: clusterIdToUse })
    .in('id', cluster.faces.map(f => f.id));
}
```

4. **Select Representative Face**:
```typescript
// Choose highest quality detection as representative
const representative = cluster.faces.reduce((best, face) =>
  face.confidence > best.confidence ? face : best
);

await supabase
  .from('face_clusters')
  .update({ representative_detection_id: representative.id })
  .eq('id', clusterIdToUse);
```

### Output
- `face_clusters` records for each unique individual
- Updated `face_detections` with `face_cluster_id` links

---

## 🔗 Pipeline Integration

Update `supabase/functions/process-video/index.ts` to add face processing:

```typescript
// Existing steps
await transcribeVideo(clipId);
await analyzeAtoms(clipId);

// NEW: Phase 4 face processing
try {
  console.log('Starting face detection...');
  await invokeFaceDetect(clipId, videoUrl);

  console.log('Generating face embeddings...');
  await invokeFaceEmbed(clipId);

  console.log('Clustering faces...');
  await invokeFaceCluster(clipId);

  console.log('Face processing complete');
} catch (error) {
  console.error('Face processing failed:', error);
  // Don't fail entire pipeline if faces fail
  // Just log and continue
}

// Mark clip as ready
await supabase
  .from('clips')
  .update({ status: 'ready' })
  .eq('id', clipId);
```

**Important:** Face processing failures should NOT block the pipeline. Videos without faces should still be marked as ready.

---

## 📊 Database Helpers

### SQL Function: find_similar_cluster

Create this Postgres function for efficient cluster matching:

```sql
CREATE OR REPLACE FUNCTION find_similar_cluster(
  query_embedding vector(512),
  similarity_threshold float DEFAULT 0.6
)
RETURNS TABLE (
  id uuid,
  similarity float
) AS $$
  SELECT
    fc.id,
    1 - (fd.face_embedding <=> query_embedding) as similarity
  FROM face_clusters fc
  JOIN face_detections fd
    ON fc.representative_detection_id = fd.id
  WHERE 1 - (fd.face_embedding <=> query_embedding) > similarity_threshold
  ORDER BY similarity DESC
  LIMIT 1;
$$ LANGUAGE sql;
```

### Helper: Cosine Similarity

```typescript
function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magA * magB);
}
```

---

## ✅ Testing Checklist

### Test Case 1: Single Person Video
**Scenario:** Interview with one person on camera

**Expected:**
- ✅ Multiple face_detections created (one per second)
- ✅ All detections have embeddings
- ✅ Single face_cluster created
- ✅ All detections linked to same cluster
- ✅ Representative detection selected

**Verify:**
```sql
SELECT
  COUNT(*) as total_faces,
  COUNT(DISTINCT face_cluster_id) as unique_people
FROM face_detections
WHERE clip_id = 'your-clip-id';
-- Should return: total_faces > 0, unique_people = 1
```

### Test Case 2: Two Person Video
**Scenario:** Conversation between two people

**Expected:**
- ✅ Detections for both people
- ✅ Two distinct face_clusters
- ✅ Faces correctly assigned to respective clusters

**Verify:**
```sql
SELECT
  face_cluster_id,
  COUNT(*) as face_count
FROM face_detections
WHERE clip_id = 'your-clip-id'
GROUP BY face_cluster_id;
-- Should return 2 rows (one per person)
```

### Test Case 3: No Faces Video
**Scenario:** Screencast or landscape video with no people

**Expected:**
- ✅ Zero face_detections created
- ✅ Clip still marked as 'ready'
- ✅ No errors thrown

### Test Case 4: Cross-Clip Matching
**Scenario:** Same person appears in two different clips

**Expected:**
- ✅ Process first clip → creates face_cluster
- ✅ Process second clip → detects same person
- ✅ Both clips link to SAME face_cluster
- ✅ Single cluster with faces from both clips

**Verify:**
```sql
SELECT
  fc.id,
  fc.cluster_key,
  COUNT(DISTINCT fd.clip_id) as clip_count,
  COUNT(*) as total_detections
FROM face_clusters fc
JOIN face_detections fd ON fd.face_cluster_id = fc.id
GROUP BY fc.id, fc.cluster_key
HAVING COUNT(DISTINCT fd.clip_id) > 1;
-- Should show clusters appearing in multiple clips
```

---

## 🚨 Common Issues & Solutions

### Issue: Models not loading in Edge Function
**Solution:** Ensure model files are included in deployment:
```bash
# Create models directory
mkdir -p supabase/functions/_shared/models

# Download face-api.js models
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/ssd_mobilenetv1_model-weights_manifest.json
# ... (download all model files)
```

### Issue: Clustering creates too many clusters (over-segmentation)
**Solution:** Increase `EPS` parameter from 0.35 to 0.40 or 0.45

### Issue: Clustering merges different people (under-segmentation)
**Solution:** Decrease `EPS` parameter from 0.35 to 0.30 or 0.25

### Issue: Cross-clip matching not working
**Solution:** Check that `find_similar_cluster` function uses correct similarity threshold (try lowering from 0.6 to 0.5)

### Issue: Processing takes too long
**Solutions:**
- Reduce frame rate from 1 FPS to 0.5 FPS
- Process frames in parallel (batch of 10 at a time)
- Skip low-quality detections (confidence < 0.8)

---

## 📈 Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Detection Rate | 95%+ | Faces detected / faces present |
| Clustering Accuracy | 90%+ | Correct assignments / total faces |
| False Positives | <5% | Non-face detections / total detections |
| Processing Time | <30 sec/min | Total processing time / video duration |
| Cross-clip Matching | 85%+ | Same person correctly matched |

---

## 🎓 Implementation Tips

### Tip 1: Model Caching
Load face-api.js models ONCE per Edge Function instance (cold start), then cache in memory:

```typescript
let modelsLoaded = false;

async function ensureModelsLoaded() {
  if (modelsLoaded) return;

  await faceapi.nets.ssdMobilenetv1.loadFromUri('./models');
  await faceapi.nets.faceLandmark68Net.loadFromUri('./models');
  await faceapi.nets.faceRecognitionNet.loadFromUri('./models');

  modelsLoaded = true;
}
```

### Tip 2: Quality Filtering
Skip low-quality detections to improve clustering accuracy:

```typescript
const MIN_FACE_SIZE = 0.05; // 5% of frame
const MIN_CONFIDENCE = 0.8;

if (detection.score < MIN_CONFIDENCE) continue;
if (detection.box.width < frameWidth * MIN_FACE_SIZE) continue;
```

### Tip 3: Batch Processing
Process multiple frames concurrently:

```typescript
const BATCH_SIZE = 10;

for (let i = 0; i < frames.length; i += BATCH_SIZE) {
  const batch = frames.slice(i, i + BATCH_SIZE);
  await Promise.all(batch.map(frame => detectFacesInFrame(frame)));
}
```

---

## ⏭️ What's Next: Phase 5

Phase 4 provides the foundation. Phase 5 will add:

- **Face Labeling Modal:** UI to present unlabeled clusters to users
- **Entity Linking:** Connect face_clusters to entities table
- **Face Timeline:** Visualize when each person appears
- **Cluster Management:** Merge/split clusters if needed

Phase 5 depends on Phase 4 being complete and tested.

---

## 📚 Reference Documents

- **Phase-4-Technical-Specification.docx** - Complete technical details
- **facial-recognition-entity-labeling-spec.md** - Original design document
- **IMPLEMENTATION-CHECKLIST-PHASE-4.md** - Step-by-step implementation guide

---

**Estimated Time:** 2-3 weeks (20-30 hours)
**Phase 4 Status:** 🔴 Ready to Start
**Last Updated:** February 12, 2026

---

## 🤝 Need Help?

If you encounter issues:
1. Check the Testing Checklist above
2. Review Common Issues & Solutions
3. Verify database schema with `\d face_detections` and `\d face_clusters`
4. Test with simple single-person video first

**Questions?** Reference the Technical Specification document for detailed explanations of algorithms and architecture decisions.
