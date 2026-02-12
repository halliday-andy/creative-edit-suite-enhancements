# Creative Edit Suite - Entity & Facial Recognition System
## Project Overview for Lovable

---

## 🎯 Project Goal

Build an intelligent knowledge graph and facial recognition system for the Creative Edit Suite that automatically identifies and tracks people, locations, objects, and concepts across video content. This enables powerful search, organization, and editing capabilities based on who appears in videos and what is discussed.

---

## 🧠 The Problem We're Solving

**Current State:**
- Videos are processed into "atoms" (semantic segments) with transcripts
- No way to track WHO appears in videos visually
- No way to search for specific people across multiple videos
- No knowledge graph connecting related entities
- Manual entity management is tedious and error-prone

**Desired State:**
- Automatic detection and recognition of people's faces in videos
- Knowledge graph linking people, locations, objects, and concepts
- Search by person name to find all appearances across videos
- Editor shows who is on-screen vs who is mentioned in speech
- Intelligent entity extraction from transcripts

---

## 🏗️ System Architecture Overview

### Three Main Components:

**1. Knowledge Graph (Entities)**
- Store entities: PERSON, LOCATION, OBJECT, CONCEPT
- Track relationships between entities and video clips
- Enable semantic search using vector embeddings

**2. Facial Recognition**
- Detect faces in video frames
- Generate face embeddings (512d vectors)
- Cluster faces by unique individual
- Allow users to label clusters with person names

**3. Integration Layer**
- Link face detections to entity records
- Enrich atoms with visual entity data
- Enable search by person/entity across video library

---

## 📋 7-Phase Implementation Plan

### **Phase 1: Database Foundation** (1-2 weeks)
**What:** Create 4 tables to store entities, face detections, and clusters
**Deliverable:** Database schema with pgvector support
**Dependencies:** None
**Status:** Ready to implement

### **Phase 2: Entity Management UI** (1 week)
**What:** Build CRUD interface for managing entities
**Deliverable:** `/entities` page where users can create/edit people, locations, etc.
**Dependencies:** Phase 1
**Status:** Waiting

### **Phase 3: Entity-Aware Atomization** (1 week)
**What:** Modify video processing to auto-detect entities from transcripts
**Deliverable:** Gemini automatically identifies entities when creating atoms
**Dependencies:** Phase 1, 2
**Status:** Waiting
**Milestone:** 🎉 **MVP Complete** - Manual entity management + auto-detection

### **Phase 4: Face Detection & Clustering** (2 weeks)
**What:** Implement face detection, embeddings, and clustering algorithms
**Deliverable:** System groups faces by unique individual
**Dependencies:** Phase 1
**Status:** Waiting

### **Phase 5: Face Labeling UI** (1 week)
**What:** Build interface for users to label face clusters with names
**Deliverable:** Face labeling page showing detected faces to be identified
**Dependencies:** Phase 2, 4
**Status:** Waiting

### **Phase 6: Atom-Face Integration** (1 week)
**What:** Connect face detections to atom timeline
**Deliverable:** Editor shows who is visible on-screen during each atom
**Dependencies:** Phase 3, 5
**Status:** Waiting

### **Phase 7: Enhanced Search** (1 week)
**What:** Add entity-based search and filtering
**Deliverable:** Search clips by person name, location, or entity
**Dependencies:** All previous phases
**Status:** Waiting
**Milestone:** 🎉 **Full System Complete**

---

## 💡 Key Concepts

### Entities
Structured knowledge graph nodes representing:
- **PERSON** - John Doe, Jane Smith
- **LOCATION** - San Francisco, Conference Room
- **OBJECT** - iPhone, Whiteboard
- **CONCEPT** - AI Strategy, Q4 Goals

### Face Detection
- Extract faces from video frames (1 frame/second)
- Generate 512d embeddings for each face
- Group similar faces into clusters (same person)

### Face Clusters
- Each cluster = one unique individual
- Initially "unlabeled" (no name)
- User labels cluster → links to PERSON entity

### Atom Enrichment
Atoms gain two types of entity data:
- **Mentioned entities** (from transcript) - "John discussed the strategy"
- **Visible entities** (from face detection) - John's face appears on screen

---

## 🔧 Technical Stack

**Database:** Supabase PostgreSQL with pgvector extension
**Embeddings:**
- Entities: 1536d (OpenAI text-embedding-3-small)
- Faces: 512d (face-api.js or InsightFace)
**Face Detection:** face-api.js (JavaScript) or InsightFace (Python)
**Clustering:** DBSCAN algorithm
**Frontend:** React + TypeScript + shadcn/ui (existing)
**Processing:** Supabase Edge Functions (Deno)

---

## ✨ End User Experience

### For Content Creators:
1. Upload interview video with guest "Sarah Chen"
2. System automatically:
   - Detects Sarah's face throughout video
   - Extracts "Sarah Chen" from transcript
   - Links both to PERSON entity
3. User confirms face cluster = "Sarah Chen"
4. Future videos: System auto-recognizes Sarah
5. Search "Sarah Chen" → finds all appearances

### For Editors:
1. Open video in editor
2. View atoms in timeline
3. Each atom shows:
   - 🗣️ Who is mentioned in speech
   - 👁️ Who is visible on screen
4. Filter atoms by person
5. Create highlight reel of specific person

### For Researchers:
1. Upload 100 interview videos
2. System builds knowledge graph automatically
3. Search: "What did anyone say about AI?"
4. Search: "Show me clips with John and Sarah together"
5. Discover patterns across entire corpus

---

## 🎯 Success Metrics

**MVP (After Phase 3):**
- Can manually create/edit entities
- Video processing auto-detects mentioned entities
- Can search clips by entity name

**Full System (After Phase 7):**
- Face detection accuracy > 85%
- Face recognition works across videos
- Search by person returns all appearances
- Processing time < 5 minutes per 10-minute video

---

## 🚀 Implementation Approach

**Sequential Phases:** Complete Phase 1 → Test → Phase 2 → Test → etc.

**Why Sequential:**
- Each phase builds on previous phases
- Easier to debug and verify
- Can deploy MVP after Phase 3
- Can pause after MVP if needed

**Total Timeline:** 8-10 weeks for full system

---

## 📊 Database Overview

### New Tables (4):

1. **entities** - Knowledge graph nodes (people, locations, objects, concepts)
2. **clip_entities** - Links entities to video clips
3. **face_detections** - Individual face bounding boxes + embeddings
4. **face_clusters** - Groups of faces belonging to same person

### Vector Search:
- Uses pgvector extension
- Entity embeddings: 1536 dimensions
- Face embeddings: 512 dimensions
- HNSW indexes for fast similarity search

---

## 🎬 Ready to Start?

**First Step:** Implement Phase 1 (Database Foundation)
- Enable pgvector extension
- Create 4 new tables
- Set up indexes and constraints
- Test with sample data

**Next:** I'll provide you with detailed Phase 1 implementation instructions.

---

## 💬 Questions?

**Q: Why facial recognition AND entity extraction?**
A: Facial recognition identifies WHO is visible on screen. Entity extraction identifies WHO is mentioned in speech. Combining both gives complete picture.

**Q: What if face detection fails?**
A: System still works with entity extraction from transcripts. Face recognition is enhancement, not requirement.

**Q: Can users correct mistakes?**
A: Yes. Users can manually edit entities, merge clusters, and update labels throughout the system.

**Q: Performance impact?**
A: Face detection adds ~2-3x to processing time. Can be made optional or run async.

---

**Let's build this! Starting with Phase 1...** 🚀
