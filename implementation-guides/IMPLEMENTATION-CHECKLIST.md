# Implementation Checklist - Entity System & Facial Recognition

Track your progress through all implementation phases with this comprehensive checklist.

## 📊 Progress Overview

```
Phase 1: Database Foundation       [ ] 0/10 complete
Phase 2: Entity Management UI      [ ] 0/12 complete
Phase 3: Entity-Aware Atomization [ ] 0/10 complete
Phase 4: Face Detection            [ ] 0/12 complete
Phase 5: Face Labeling UI          [ ] 0/8 complete
Phase 6: Atom-Face Integration     [ ] 0/6 complete
Phase 7: Enhanced Search           [ ] 0/8 complete

Total Progress: [ ] 0/66 complete
```

---

## Phase 1: Database Foundation ⭐ START HERE

**Estimated Time:** 1-2 hours
**Priority:** HIGH
**Status:** Not Started

### Database Schema
- [ ] Created new migration file in `supabase/migrations/`
- [ ] Copied schema from `entity-system-migration.sql`
- [ ] Applied migration successfully (no errors)
- [ ] Verified pgvector extension is enabled
- [ ] Verified pg_trgm extension is enabled

### Tables Created
- [ ] `entities` table exists with correct columns
- [ ] `clip_entities` table exists
- [ ] `face_detections` table exists
- [ ] `face_clusters` table exists
- [ ] All foreign key constraints created

### Indices & Performance
- [ ] GIN index on entities.name for fuzzy search
- [ ] IVFFlat index on entities.embedding for vector search
- [ ] IVFFlat index on face_detections.face_embedding
- [ ] Indices on all foreign keys
- [ ] Helper functions created (get_clip_entities, find_similar_entities)

### Testing
- [ ] Inserted sample entities successfully
- [ ] Queried entities by type (works)
- [ ] Fuzzy name search works (ILIKE)
- [ ] Helper functions execute without errors
- [ ] RLS policies configured (permissive for Lovable)

### TypeScript Integration
- [ ] Added Entity interface to types file
- [ ] Added ClipEntity interface
- [ ] Added FaceDetection interface
- [ ] Added FaceCluster interface
- [ ] Created entityService.ts with CRUD operations
- [ ] Tested entity service in console (create, read, update, delete)

**Phase 1 Complete:** [ ] All checkboxes above checked

---

## Phase 2: Entity Management UI

**Estimated Time:** 1 week
**Priority:** HIGH
**Status:** Not Started
**Prerequisites:** Phase 1 complete

### Page Structure
- [ ] Created `/src/pages/Entities.tsx` route
- [ ] Added navigation link to Entities page
- [ ] Page loads without errors
- [ ] Basic layout renders (header, grid, filters)

### EntityList Component
- [ ] Created `EntityList.tsx` component
- [ ] Grid layout (3-4 columns, responsive)
- [ ] Loading skeleton state
- [ ] Empty state with helpful message
- [ ] Entities fetch from database on mount

### EntityCard Component
- [ ] Created `EntityCard.tsx` component
- [ ] Displays entity name, type, description
- [ ] Type badge with icon (User, MapPin, Package, Lightbulb)
- [ ] Type-specific colors (blue=person, green=location, purple=object, orange=concept)
- [ ] Shows alias list
- [ ] Shows clip count
- [ ] Hover effect and cursor pointer
- [ ] Click opens entity detail view

### CreateEntityModal Component
- [ ] Created `CreateEntityModal.tsx` component
- [ ] Opens from "Create Entity" button
- [ ] Form fields: name (required), type (radio), description, aliases
- [ ] Type validation (only 4 valid types)
- [ ] Name validation (required, max 200 chars)
- [ ] Alias input (comma-separated, max 20 aliases)
- [ ] Submit creates entity in database
- [ ] Success toast notification
- [ ] Error handling for duplicate names
- [ ] Form resets after successful creation

### EntityDetailView Component
- [ ] Created `EntityDetailView.tsx` component
- [ ] Route: `/entities/:id`
- [ ] Fetches entity by ID
- [ ] Displays full entity information
- [ ] Shows all clips featuring this entity
- [ ] Edit button (opens edit modal)
- [ ] Delete button (with confirmation)
- [ ] Back navigation to entity list

### Search & Filters
- [ ] Search input filters by name/alias
- [ ] Type filter (All, People, Locations, Objects, Concepts)
- [ ] Search is case-insensitive
- [ ] Filters work in combination
- [ ] Search results update in real-time

### EntityChip Component
- [ ] Created `EntityChip.tsx` component
- [ ] Small badge with type icon
- [ ] Three sizes (sm, md, lg)
- [ ] Click opens entity detail (optional)
- [ ] Used in ClipCard, AtomInspector

**Phase 2 Complete:** [ ] All checkboxes above checked

---

## Phase 3: Entity-Aware Atomization

**Estimated Time:** 1 week
**Priority:** HIGH
**Status:** Not Started
**Prerequisites:** Phase 1 complete (Phase 2 recommended)

### Edge Function Modifications
- [ ] Located existing atomization Edge Function
- [ ] Backed up current version
- [ ] Added entity fetching before atomization
- [ ] Entities query returns id, name, type, aliases

### Gemini Prompt Enhancement
- [ ] Created entity context string (name, type, UUID)
- [ ] Added entity context to Gemini prompt
- [ ] Prompt explains how to use entity UUIDs
- [ ] Prompt instructs to use subject_entity_id and object_entity_id
- [ ] Tested prompt with sample data

### Atom Data Schema Update
- [ ] atoms_data includes subject_entity_id field
- [ ] atoms_data includes object_entity_id field
- [ ] Subject_text still included as fallback
- [ ] Object_text still included as fallback
- [ ] Schema validated with sample atom

### Entity Reference Storage
- [ ] Gemini response parsed correctly
- [ ] Entity UUIDs validated before storage
- [ ] Invalid UUIDs set to null with warning
- [ ] atoms_data updated with entity references
- [ ] Database update successful

### clip_entities Population
- [ ] Entity mentions aggregated from atoms
- [ ] Subject entities counted
- [ ] Object entities counted
- [ ] First appearance timestamp calculated
- [ ] clip_entities records created
- [ ] Duplicate prevention (UNIQUE constraint)

### Testing
- [ ] Processed test video with known entities
- [ ] Verified atoms contain entity_id references
- [ ] Verified clip_entities records created
- [ ] Entity mentions count is accurate
- [ ] No errors in Edge Function logs

**Phase 3 Complete:** [ ] All checkboxes above checked

---

## Phase 4: Face Detection & Clustering

**Estimated Time:** 2 weeks
**Priority:** MEDIUM
**Status:** Not Started
**Prerequisites:** Phase 1 complete

### Technology Selection
- [ ] Chose face detection library (face-api.js, InsightFace, or AWS Rekognition)
- [ ] Installed dependencies in Edge Function
- [ ] Tested library in isolation (sample image)

### Edge Function: detect-faces
- [ ] Created `supabase/functions/detect-faces/index.ts`
- [ ] Downloads video from Supabase Storage
- [ ] Extracts frames (1 per second recommended)
- [ ] Detects faces in each frame
- [ ] Generates 512d face embeddings
- [ ] Calculates bounding boxes (normalized 0-1)
- [ ] Calculates quality metrics (blur score, size)
- [ ] Generates thumbnail for each face
- [ ] Stores in face_detections table

### Edge Function: cluster-faces
- [ ] Created `supabase/functions/cluster-faces/index.ts`
- [ ] Fetches all detections for a clip
- [ ] Calculates cosine similarity between embeddings
- [ ] Groups faces by similarity (threshold: 0.6)
- [ ] Creates face_clusters for unique individuals
- [ ] Assigns representative_detection_id (best quality face)
- [ ] Updates face_detections with face_cluster_id

### Auto-Matching Existing Clusters
- [ ] Fetches existing labeled face_clusters
- [ ] Compares new faces to existing cluster representatives
- [ ] Auto-assigns entity_id if similarity > 0.65
- [ ] Creates new unlabeled cluster if no match
- [ ] Logs matching results (auto-labeled vs needs labeling)

### Integration with Video Processing
- [ ] Face detection triggered after atomization
- [ ] Face clustering runs after detection
- [ ] Processing pipeline handles face detection errors gracefully
- [ ] clips.face_coordinates JSONB populated
- [ ] face_coordinates includes cluster_id, entity_id, appearances

### Testing
- [ ] Tested with video containing 1 person
- [ ] Tested with video containing multiple people
- [ ] Verified faces grouped correctly by person
- [ ] Verified embeddings stored correctly
- [ ] Verified auto-matching works for known faces
- [ ] Performance acceptable (<30s per minute of video)

**Phase 4 Complete:** [ ] All checkboxes above checked

---

## Phase 5: Face Labeling UI

**Estimated Time:** 1 week
**Priority:** MEDIUM
**Status:** Not Started
**Prerequisites:** Phase 1, 4 complete

### FaceLabelingModal Component
- [ ] Created `FaceLabelingModal.tsx` component
- [ ] Opens automatically after video processing (if unlabeled faces)
- [ ] Fetches unlabeled face_clusters for clip
- [ ] Displays face thumbnails in grid
- [ ] Shows appearance count for each face
- [ ] Entity dropdown populated with PERSON entities

### Entity Selection Flow
- [ ] Dropdown shows existing entities by name
- [ ] "Create New" button opens CreateEntityModal
- [ ] New entity immediately available in dropdown
- [ ] Selected entity stored in component state
- [ ] "Skip" button removes face from labeling queue

### Save & Update Flow
- [ ] "Save Labels" button enabled only if selections made
- [ ] Saves label → updates face_clusters.entity_id
- [ ] Updates face_clusters.is_labeled = true
- [ ] Updates face_clusters.labeled_by_user = true
- [ ] Updates all face_detections.entity_id in cluster
- [ ] Triggers atom enrichment Edge Function
- [ ] Updates clip_entities table
- [ ] Success notification shown

### AutoLabelingBanner Component
- [ ] Created `AutoLabelingBanner.tsx` component
- [ ] Shows after face clustering completes
- [ ] Displays count of auto-labeled faces
- [ ] Displays count of faces needing labeling
- [ ] "Label New Faces" button opens FaceLabelingModal
- [ ] Banner dismissible if no faces need labeling

### FaceTimeline Component
- [ ] Created `FaceTimeline.tsx` component
- [ ] Visual timeline bar showing clip duration
- [ ] Face appearance indicators at correct timestamps
- [ ] Hover shows entity name and timestamp
- [ ] Legend below timeline with entity chips
- [ ] Appearance counts displayed

**Phase 5 Complete:** [ ] All checkboxes above checked

---

## Phase 6: Atom-Face Integration

**Estimated Time:** 1 week
**Priority:** MEDIUM
**Status:** Not Started
**Prerequisites:** Phase 3, 5 complete

### Edge Function: enrich-atoms-with-faces
- [ ] Created `supabase/functions/enrich-atoms-with-faces/index.ts`
- [ ] Fetches clip atoms_data
- [ ] Fetches transcript for timestamp calculation
- [ ] Fetches labeled face_detections for clip
- [ ] Calculates atom time ranges from word indices

### Spatial-Temporal Matching
- [ ] Matches faces to atoms by timestamp overlap
- [ ] Groups faces by entity within each atom
- [ ] Calculates appearance count per entity per atom
- [ ] Calculates average confidence per entity per atom

### Atom Data Enhancement
- [ ] Adds visible_entities array to each atom
- [ ] visible_entities includes entity_id, entity_name, entity_type
- [ ] visible_entities includes source: 'face_detection'
- [ ] visible_entities includes confidence and appearance_count
- [ ] Updates clips.atoms_data with enriched atoms

### Audio-Visual Entity Merging
- [ ] Creates all_entities array merging audio + visual
- [ ] Audio entities marked with source: 'audio', role: 'subject'/'object'
- [ ] Visual entities marked with source: 'visual', role: 'visible'
- [ ] Deduplicates entities (same person in audio and visual)

### UI Display Updates
- [ ] Modified AtomInspector to show visible_entities
- [ ] Modified AtomInspector to show all_entities
- [ ] Entity chips show source badges (🎧 audio, 📹 video)
- [ ] Entity role badges (🎤 speaking, 📝 mentioned, 👁️ visible)
- [ ] Face detection details shown (frame count, confidence)

### Automatic Triggering
- [ ] Database trigger created on face_clusters.is_labeled
- [ ] Trigger calls enrich-atoms-with-faces Edge Function
- [ ] Enrichment happens automatically after user labels faces
- [ ] All clips with labeled faces get enriched

**Phase 6 Complete:** [ ] All checkboxes above checked

---

## Phase 7: Enhanced Search

**Estimated Time:** 1 week
**Priority:** LOW
**Status:** Not Started
**Prerequisites:** Phase 2, 3 complete (6 recommended)

### Search Filter Enhancements
- [ ] Added entity dropdown to SearchFilters component
- [ ] Entity dropdown populated with all entities
- [ ] Entity filter updates search results
- [ ] Multiple entity selection supported (optional)

### Entity Source Filtering
- [ ] Added radio buttons: Any, Audio only, Video only
- [ ] Audio only filters atoms with subject_entity_id/object_entity_id
- [ ] Video only filters atoms with visible_entities
- [ ] Filter works in combination with entity selection

### Search Service Updates
- [ ] Modified atomSearch to support entity filters
- [ ] Pre-filters clips using clip_entities table
- [ ] Filters atoms client-side by entity_id
- [ ] Filters atoms by entity source (audio/visual)
- [ ] Returns matching atoms with clip context

### Entity Autocomplete
- [ ] Search bar suggests entities as user types
- [ ] Autocomplete shows entity type icons
- [ ] Click on suggestion adds entity filter
- [ ] Recent entities shown first (optional)

### Entity Detail Search Integration
- [ ] "View all clips" link on entity detail page
- [ ] Link pre-filters search by entity
- [ ] Search results show why entity matches (audio vs visual)

### Performance Optimization
- [ ] Entity filter uses database indices
- [ ] Search response time <2 seconds
- [ ] Large result sets paginated
- [ ] Entity counts cached (optional)

**Phase 7 Complete:** [ ] All checkboxes above checked

---

## 🎯 Final Verification

### Core Functionality
- [ ] Users can create entities via UI
- [ ] Videos process with entity-aware atomization
- [ ] Atoms include entity references (subject_entity_id, object_entity_id)
- [ ] Faces detected in videos automatically
- [ ] Users can label detected faces
- [ ] Labeled faces link to entities
- [ ] Atoms show both audio and visual entities
- [ ] Search filters by entity work correctly

### Performance
- [ ] Entity-aware atomization adds <2s per clip
- [ ] Face detection processes 1 min video in <30s
- [ ] Search returns results in <2s
- [ ] UI remains responsive during processing

### User Experience
- [ ] Entity creation intuitive (no training)
- [ ] Face labeling takes <30s per face
- [ ] Entity chips visually distinct by type
- [ ] Auto-labeling reduces manual work
- [ ] Search results clearly show entity matches

### Data Integrity
- [ ] No orphaned records (foreign keys enforced)
- [ ] Entity names unique per type
- [ ] Face embeddings stored correctly
- [ ] Atom data schema consistent
- [ ] No data loss during migrations

### Error Handling
- [ ] Graceful degradation if entity fetch fails
- [ ] Face detection errors don't break processing
- [ ] Invalid entity IDs handled gracefully
- [ ] UI shows clear error messages
- [ ] Database constraints prevent invalid data

---

## 📊 Progress Summary

Update this section as you complete phases:

```
✅ Phase 1: Database Foundation       [10/10] COMPLETE
⬜ Phase 2: Entity Management UI      [ 0/12] Not Started
⬜ Phase 3: Entity-Aware Atomization  [ 0/10] Not Started
⬜ Phase 4: Face Detection             [ 0/12] Not Started
⬜ Phase 5: Face Labeling UI           [ 0/8] Not Started
⬜ Phase 6: Atom-Face Integration      [ 0/6] Not Started
⬜ Phase 7: Enhanced Search            [ 0/8] Not Started

Overall Progress: [10/66] 15% Complete
```

**Current Phase:** Phase 1
**Next Phase:** Phase 2 (Entity Management UI)
**Target Completion:** [Your target date]

---

## 🎉 Milestones

- [ ] **MVP Complete** (Phases 1-3): Basic entity system working
- [ ] **Facial Recognition Complete** (Phases 1-6): Full face detection & labeling
- [ ] **Full System Complete** (All Phases): Entity system + facial recognition + enhanced search

**Congratulations on completing each phase!** 🚀
