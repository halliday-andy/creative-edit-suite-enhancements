# Phase 4 Implementation Checklist

**Project:** Creative Edit Suite - Face Detection & Clustering
**Phase:** 4 of 7
**Status:** Not Started

Use this checklist to track Phase 4 implementation progress. Check off items as you complete them.

---

## 📋 Pre-Implementation Setup

### Environment Verification
- [ ] Database schema verified (face_detections and face_clusters tables exist)
- [ ] pgvector extension enabled in Supabase (`CREATE EXTENSION IF NOT EXISTS vector;`)
- [ ] Supabase Edge Functions environment working
- [ ] Video processing pipeline functional (can process test clip successfully)
- [ ] Node.js/npm available for installing face-api.js

### Model Setup
- [ ] Download face-api.js model files:
  - [ ] ssdMobilenetv1 (face detection)
  - [ ] faceLandmark68Net (landmarks)
  - [ ] faceRecognitionNet (embeddings)
- [ ] Place models in `supabase/functions/_shared/models/` directory
- [ ] Verify models load correctly in local test

### Test Data Prepared
- [ ] Single-person test video uploaded (< 1 minute)
- [ ] Two-person test video uploaded (< 1 minute)
- [ ] No-faces test video uploaded (screencast or landscape)
- [ ] Test video IDs recorded for testing

---

## 🔧 Edge Function 1: face-detect

### File Creation
- [ ] Create `supabase/functions/face-detect/index.ts`
- [ ] Install face-api.js dependency
- [ ] Import required libraries (face-api.js, Supabase client)

### Core Functionality
- [ ] Implement model loading with caching
- [ ] Create video download helper
- [ ] Implement frame extraction (FFmpeg at 1 FPS)
- [ ] Implement face detection loop
- [ ] Normalize bounding boxes to 0-1 range
- [ ] Insert face_detections records

### Error Handling
- [ ] Handle no faces detected (success case)
- [ ] Handle video download failures (retry logic)
- [ ] Handle FFmpeg errors
- [ ] Add logging for debugging

### Testing
- [ ] Test with single-person video
- [ ] Test with two-person video
- [ ] Test with no-faces video
- [ ] Verify face_detections records created
- [ ] Verify bounding box coordinates are normalized (0-1)
- [ ] Check performance (processing time per frame)

---

## 🔧 Edge Function 2: face-embed

### File Creation
- [ ] Create `supabase/functions/face-embed/index.ts`
- [ ] Import face-api.js faceRecognitionNet model
- [ ] Import Supabase client

### Core Functionality
- [ ] Load faceRecognitionNet model
- [ ] Fetch face_detections without embeddings
- [ ] Implement face cropping from frames
- [ ] Generate face descriptors
- [ ] Normalize embeddings to unit length
- [ ] Update face_detections with embeddings

### Helper Functions
- [ ] `cropFaceFromFrame()` - extract face region
- [ ] `normalizeVector()` - normalize to unit length
- [ ] `getFrameAtTimestamp()` - get specific frame from video

### Testing
- [ ] Test embedding generation on single face
- [ ] Verify embeddings are correct dimension (128d or 512d)
- [ ] Verify embeddings normalized (magnitude = 1.0)
- [ ] Test batch processing (multiple faces)
- [ ] Check processing time per face

---

## 🔧 Edge Function 3: face-cluster

### File Creation
- [ ] Create `supabase/functions/face-cluster/index.ts`
- [ ] Install/implement DBSCAN library
- [ ] Import Supabase client

### Helper Functions
- [ ] `cosineSimilarity()` - calculate similarity between embeddings
- [ ] `dbscan()` - DBSCAN clustering algorithm
- [ ] `calculateCentroid()` - compute cluster centroid
- [ ] `findBestRepresentative()` - select highest quality face

### Core Functionality
- [ ] Fetch face_detections with embeddings
- [ ] Implement DBSCAN clustering (eps=0.35, minSamples=2)
- [ ] Create cluster centroid calculation
- [ ] Implement cross-clip matching logic
- [ ] Create new face_clusters for unique people
- [ ] Link face_detections to clusters
- [ ] Select representative detection

### Database Functions
- [ ] Create `find_similar_cluster()` SQL function
- [ ] Test similarity search with pgvector
- [ ] Optimize query performance with indices

### Testing
- [ ] Test clustering on single-person video (expect 1 cluster)
- [ ] Test clustering on two-person video (expect 2 clusters)
- [ ] Test cross-clip matching (same person in 2 clips)
- [ ] Verify representative selection (highest confidence)
- [ ] Test with edge cases (side profiles, partial faces)

---

## 🔗 Pipeline Integration

### Update process-video Function
- [ ] Add face-detect invocation after analyze-atoms
- [ ] Add face-embed invocation after face-detect
- [ ] Add face-cluster invocation after face-embed
- [ ] Implement error handling (don't block pipeline if faces fail)
- [ ] Add logging for each step
- [ ] Update clip status to 'ready' after completion

### Testing
- [ ] Test full pipeline with single-person video
- [ ] Test full pipeline with two-person video
- [ ] Test full pipeline with no-faces video
- [ ] Verify all functions execute in sequence
- [ ] Verify clip marked as 'ready' even if face processing fails

---

## 🧪 End-to-End Testing

### Test Case 1: Single Person Interview
- [ ] Upload test video
- [ ] Wait for processing to complete
- [ ] Verify face_detections created
- [ ] Verify embeddings populated
- [ ] Verify single face_cluster created
- [ ] Verify all detections linked to same cluster
- [ ] Check representative detection selected

### Test Case 2: Two Person Conversation
- [ ] Upload test video
- [ ] Wait for processing to complete
- [ ] Verify detections for both people
- [ ] Verify two distinct clusters
- [ ] Verify faces correctly assigned
- [ ] Check no cross-contamination between clusters

### Test Case 3: No Faces (Screencast)
- [ ] Upload test video
- [ ] Wait for processing to complete
- [ ] Verify zero detections created
- [ ] Verify clip still marked 'ready'
- [ ] Verify no errors in logs

### Test Case 4: Cross-Clip Matching
- [ ] Process first clip with person A
- [ ] Record cluster ID for person A
- [ ] Process second clip with same person A
- [ ] Verify same cluster ID used
- [ ] Verify detections from both clips linked to same cluster

---

## 📊 Performance Testing

### Metrics Collection
- [ ] Measure frame extraction time
- [ ] Measure face detection time per frame
- [ ] Measure embedding generation time per face
- [ ] Measure clustering time
- [ ] Calculate total processing time

### Performance Targets
- [ ] Detection rate: 95%+ (manual verification with sample)
- [ ] Clustering accuracy: 90%+ (manual verification)
- [ ] False positive rate: <5%
- [ ] Processing time: <30 seconds per minute of video

### Optimization (if needed)
- [ ] Reduce frame rate to 0.5 FPS if too slow
- [ ] Implement parallel frame processing
- [ ] Add quality filtering (skip low-confidence detections)
- [ ] Optimize DBSCAN parameters (eps, minSamples)

---

## 🐛 Bug Fixes & Edge Cases

### Common Issues
- [ ] Handle videos with no clear faces (very small, blurry)
- [ ] Handle multiple people entering/leaving frame
- [ ] Handle side profiles and partial faces
- [ ] Handle occlusions (hands, objects covering face)
- [ ] Handle low-light or poor quality video

### Error Scenarios
- [ ] Video file corrupted or unreadable
- [ ] FFmpeg installation missing
- [ ] Out of memory (very long video)
- [ ] Database connection timeout
- [ ] Model loading failure

---

## 📝 Documentation

### Code Documentation
- [ ] Add JSDoc comments to all functions
- [ ] Document DBSCAN parameters and tuning
- [ ] Document model choices and tradeoffs
- [ ] Add inline comments for complex logic

### User Documentation
- [ ] Update README with Phase 4 completion notes
- [ ] Document any configuration options
- [ ] Note known limitations

---

## ✅ Phase 4 Completion Criteria

### Functional Requirements
- [ ] Face detection works on variety of videos
- [ ] Embeddings generated correctly
- [ ] Clustering groups same person together
- [ ] Cross-clip matching identifies same person across videos
- [ ] Pipeline integration doesn't break existing functionality

### Quality Requirements
- [ ] All tests passing
- [ ] Performance targets met
- [ ] No critical bugs
- [ ] Code reviewed (if applicable)

### Handoff to Phase 5
- [ ] Database populated with face data
- [ ] Test videos processed successfully
- [ ] Documentation complete
- [ ] Known issues documented
- [ ] Ready for UI development (Phase 5)

---

## 📅 Progress Tracking

**Start Date:** _______________
**Expected Completion:** _______________
**Actual Completion:** _______________

**Blockers/Issues:**
-

**Notes:**
-

---

## 🎯 Next Steps After Completion

Once all checkboxes are complete:

1. ✅ Run full test suite one final time
2. ✅ Review performance metrics
3. ✅ Document any deviations from original spec
4. ✅ Prepare Phase 5 handoff notes
5. ✅ Begin Phase 5: Face Labeling UI

---

**Last Updated:** February 12, 2026
