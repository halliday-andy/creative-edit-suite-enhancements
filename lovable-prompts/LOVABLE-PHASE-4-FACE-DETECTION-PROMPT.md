# Phase 4: Face Detection & Clustering - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 4 of 7
**Duration:** 2 weeks
**Priority:** MEDIUM
**Depends On:** Phase 1 (Database)

---

## 🎯 Objective

Implement real face detection, embedding generation, and clustering to identify unique individuals in video clips. This replaces any simulated face coordinates with actual face recognition.

---

## 📋 What to Build

### 1. New Edge Function: `face-detect`

**Responsibilities:**
- Extract frames from video at regular intervals (1 frame/second)
- Detect faces in each frame using face-api.js or InsightFace
- Store face detections with bounding boxes
- Store normalized coordinates (0-1 range)

**Technology Options:**
- **face-api.js** (JavaScript, easier integration)
- **InsightFace** (Python, more accurate)
- **AWS Rekognition** (Managed service, most expensive)

**Recommended:** Start with face-api.js for MVP

### 2. New Edge Function: `face-embed`

**Responsibilities:**
- Generate 512d face embeddings for each detected face
- Use same model as face detection for consistency
- Store embeddings in `face_detections.face_embedding` column

### 3. New Edge Function: `face-cluster`

**Responsibilities:**
- Cluster face embeddings using DBSCAN or similar algorithm
- Group faces by unique individual
- Create `face_clusters` records
- Update `face_detections.face_cluster_id` to link faces to clusters

**Clustering Algorithm:**
```typescript
// Pseudo-code
function clusterFaces(faceEmbeddings) {
  // Use cosine similarity
  // Threshold: 0.6-0.7 for same person
  // DBSCAN parameters: eps=0.35, min_samples=2
  
  const clusters = dbscan(faceEmbeddings, {
    eps: 0.35,
    minSamples: 2,
    distanceFunction: cosineSimilarity
  });
  
  return clusters;
}
```

### 4. Update Processing Pipeline

**File:** `/supabase/functions/process-video/index.ts`

**Add face processing steps:**
1. After `analyze-atoms` completes
2. Trigger `face-detect`
3. Wait for completion
4. Trigger `face-embed`
5. Wait for completion
6. Trigger `face-cluster`
7. Mark clip as `ready`

---

## 🔧 Technical Implementation

### Face Detection with face-api.js

```typescript
import * as faceapi from 'face-api.js';

async function detectFaces(videoPath: string) {
  // Load models
  await faceapi.nets.ssdMobilenetv1.loadFromDisk('./models');
  await faceapi.nets.faceLandmark68Net.loadFromDisk('./models');
  await faceapi.nets.faceRecognitionNet.loadFromDisk('./models');

  // Extract frames
  const frames = await extractFrames(videoPath, { fps: 1 });

  const allDetections = [];

  for (const frame of frames) {
    const detections = await faceapi
      .detectAllFaces(frame)
      .withFaceLandmarks()
      .withFaceDescriptors();

    for (const detection of detections) {
      allDetections.push({
        timestamp: frame.timestamp,
        bbox: {
          x: detection.detection.box.x / frame.width,
          y: detection.detection.box.y / frame.height,
          width: detection.detection.box.width / frame.width,
          height: detection.detection.box.height / frame.height,
        },
        embedding: Array.from(detection.descriptor), // 128d or 512d
        confidence: detection.detection.score,
      });
    }
  }

  return allDetections;
}
```

### Embedding Storage

```typescript
async function storeFaceDetections(clipId: string, detections: any[]) {
  const inserts = detections.map(d => ({
    clip_id: clipId,
    timestamp_seconds: d.timestamp,
    bbox_x: d.bbox.x,
    bbox_y: d.bbox.y,
    bbox_width: d.bbox.width,
    bbox_height: d.bbox.height,
    face_embedding: d.embedding,
    confidence: d.confidence,
  }));

  const { error } = await supabase
    .from('face_detections')
    .insert(inserts);

  if (error) throw error;
}
```

### Clustering Implementation

```typescript
async function clusterFaces(clipId: string) {
  // Fetch all face embeddings for this clip
  const { data: faces } = await supabase
    .from('face_detections')
    .select('id, face_embedding')
    .eq('clip_id', clipId);

  if (!faces || faces.length === 0) return;

  // Run DBSCAN clustering
  const clusters = dbscan(faces, {
    eps: 0.35,
    minPts: 2,
    distance: (a, b) => 1 - cosineSimilarity(a.face_embedding, b.face_embedding),
  });

  // Create cluster records
  for (const [clusterIdx, faceIds] of clusters.entries()) {
    const clusterKey = `${clipId}-cluster-${clusterIdx}`;

    const { data: cluster } = await supabase
      .from('face_clusters')
      .insert({
        cluster_key: clusterKey,
        status: 'unlabeled',
      })
      .select('id')
      .single();

    // Link faces to cluster
    await supabase
      .from('face_detections')
      .update({ face_cluster_id: cluster.id })
      .in('id', faceIds);
  }
}
```

---

## ✅ Acceptance Criteria

- [ ] **Face detection works** - Detects faces in video frames
- [ ] **Bounding boxes accurate** - Boxes correctly positioned around faces
- [ ] **Embeddings generated** - 512d vectors stored in database
- [ ] **Clustering works** - Multiple faces of same person grouped together
- [ ] **Performance acceptable** - Processing time reasonable for 5-min video
- [ ] **No false positives** - Doesn't detect faces where none exist
- [ ] **Handles edge cases** - Works with side profiles, partial faces, etc.
- [ ] **Updates clip status** - Marks clip as ready after face processing

### Test Cases:

1. **Single person video:**
   - Process interview with one person
   - Verify one cluster created
   - Verify all face detections linked to same cluster

2. **Two person video:**
   - Process conversation between two people
   - Verify two clusters created
   - Verify faces correctly assigned to respective clusters

3. **No faces video:**
   - Process screencast or landscape video
   - Verify no face_detections created
   - Verify clip still marked ready

---

## 📚 Reference Documents

1. **facial-recognition-entity-labeling-spec.md** - Complete specifications
2. **LOVABLE-IMPLEMENTATION-PROMPT.md** - Phase 4 section

---

## ⏭️ Next Steps

After Phase 4:
1. ✅ Test with various video types
2. ✅ Tune clustering threshold
3. ✅ Verify performance on longer videos
4. ✅ Move to **Phase 5: Face Labeling UI**

---

**Estimated Time:** 2 weeks (12-16 hours)
**Phase 4 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
