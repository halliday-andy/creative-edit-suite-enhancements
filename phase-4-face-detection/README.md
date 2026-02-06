# Phase 4: Face Detection & Clustering

**Priority:** MEDIUM | **Duration:** 2 weeks

## Overview

Implement facial recognition to automatically detect and cluster unique individuals across all videos.

## What's Included

- [`facial-recognition-entity-labeling-spec.md`](./facial-recognition-entity-labeling-spec.md) - Complete facial recognition system

## What You'll Build

### Edge Functions
- `supabase/functions/detect-faces/index.ts` - Extract faces from videos
- `supabase/functions/cluster-faces/index.ts` - Group faces by person

### Process
1. Extract frames from video (1 per second)
2. Detect faces → bounding boxes
3. Generate 512d face embeddings
4. Cluster by similarity (>0.6 = same person)
5. Auto-match to existing labeled clusters
6. Store in face_detections and face_clusters tables

### Technology Options
- **face-api.js** - JavaScript, easy (recommended for MVP)
- **InsightFace** - Python, accurate (recommended for production)
- **AWS Rekognition** - Managed service (enterprise)

## Prerequisites

- Phase 1 (Database Foundation) complete
- Video processing pipeline working
- Face detection library chosen and installed

## Acceptance Criteria

- [ ] Faces detected in video frames
- [ ] Face embeddings stored correctly
- [ ] Faces clustered by unique person
- [ ] Auto-matching works for known faces
- [ ] Thumbnails generated for each face
- [ ] Performance acceptable (<30s per min of video)

## Next Phase

After completing Phase 4, move to [Phase 5: Face Labeling UI](../phase-5-face-labeling/)
