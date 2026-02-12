# Creative Edit Suite: Entity System & Facial Recognition Implementation

## Project Overview

Enhance Creative Edit Suite with a **knowledge graph entity system** and **facial recognition capabilities** to enable semantic clip discovery by tracking people, locations, objects, and concepts across videos.

## What We're Building

### Core Features

1. **Entity Management System**
   - Create and manage entities (PERSON, LOCATION, OBJECT, CONCEPT)
   - Entity relationships and knowledge graph
   - Vector embeddings for fuzzy entity matching
   - Entity timeline tracking (first seen, appearances)

2. **Entity-Aware Video Processing**
   - Modified atomization that includes entity context
   - Automatic entity linking during video processing
   - Entity references stored in atom data

3. **Facial Recognition & Labeling**
   - Detect unique faces in videos
   - Cluster faces by person across all clips
   - User-friendly face labeling interface
   - Automatic face recognition for future videos
   - Link faces to entity records

4. **Enhanced Search & Discovery**
   - Search clips by person/entity
   - Filter by audio entities (mentioned) vs visual entities (visible)
   - Entity-based clip recommendations
   - Face timeline visualization

## Implementation Phases

### Phase 1: Database Foundation (Priority: HIGH)
**Estimated: 1 week**

Implement the entity system database schema:

**New Tables:**
- `entities` - Core entity records with vector embeddings
- `clip_entities` - Junction table linking clips to entities
- `face_detections` - Individual face detections with embeddings
- `face_clusters` - Groups of faces representing unique individuals

**Schema Files:**
- See `entity-system-migration.sql` for complete SQL migration
- Add these tables to a new Supabase migration

**Key Fields:**
```typescript
// entities table
interface Entity {
  id: uuid;
  name: string;
  type: 'PERSON' | 'LOCATION' | 'OBJECT' | 'CONCEPT';
  description?: string;
  aliases: string[];
  attributes: jsonb;
  first_seen_clip_id?: uuid;
  embedding: vector(1536); // OpenAI embeddings
  created_at: timestamp;
}

// face_detections table
interface FaceDetection {
  id: uuid;
  clip_id: uuid;
  timestamp_seconds: float;
  bbox_x: float; // normalized 0-1
  bbox_y: float;
  bbox_width: float;
  bbox_height: float;
  face_embedding: vector(512); // InsightFace embeddings
  face_cluster_id?: uuid;
  entity_id?: uuid; // after labeling
  thumbnail_path?: string;
  confidence: float;
}
```

**Acceptance Criteria:**
- [ ] All tables created with proper constraints and indices
- [ ] RLS policies configured (Lovable is single-user, so allow all operations)
- [ ] pgvector extension enabled for similarity search
- [ ] Helper functions created (get_clip_entities, find_similar_entities)

### Phase 2: Entity Management UI (Priority: HIGH)
**Estimated: 1 week**

Build the entity management interface:

**New Components:**
```
src/pages/Entities.tsx           - Main entity management page
src/components/entities/
  EntityList.tsx                  - Grid of entity cards
  EntityCard.tsx                  - Individual entity display
  CreateEntityModal.tsx           - Modal for creating entities
  EntityDetailView.tsx            - Full entity view with clips
  EntityChip.tsx                  - Small entity badge/chip
  EntityFilter.tsx                - Search filter dropdown
```

**Key Features:**
- Grid layout of entity cards (3-4 columns, responsive)
- Type filters (All, People, Locations, Objects, Concepts)
- Search by name/alias
- Create entity modal with validation
- Entity detail page showing all clips with that entity

**Acceptance Criteria:**
- [ ] Users can create PERSON entities via UI
- [ ] Entities display in searchable grid
- [ ] Entity detail page shows related clips
- [ ] Entity chips render correctly with type colors
- [ ] Form validation prevents duplicate entities

### Phase 3: Entity-Aware Atomization (Priority: HIGH)
**Estimated: 1 week**

Modify the video processing pipeline to include entity context:

**Edge Function Modifications:**
```
supabase/functions/process-video/atomization.ts
```

**Changes Required:**
1. **Fetch existing entities before atomization**
   ```typescript
   const { data: entities } = await supabase
     .from('entities')
     .select('id, name, type, aliases')
     .order('name');
   ```

2. **Include entities in Gemini prompt**
   ```typescript
   const entityContext = entities.map(e =>
     `- ${e.name} [${e.type}] → UUID: ${e.id}`
   ).join('\n');

   const prompt = `
   KNOWN ENTITIES IN SYSTEM:
   ${entityContext}

   When you identify a person, location, or object that matches a known entity,
   use its UUID in subject_entity_id or object_entity_id fields.
   `;
   ```

3. **Store entity references in atoms_data**
   ```typescript
   {
     start_word_index: 142,
     end_word_index: 158,
     subject_entity_id: "uuid", // NEW
     subject_text: "Kara",
     object_entity_id: "uuid",  // NEW
     object_text: "octopus",
     action: "Hesitates to eat",
     // ... rest of atom fields
   }
   ```

4. **Create clip_entities records after atomization**
   ```typescript
   // Aggregate entity mentions from atoms
   const entityMentions = aggregateEntityMentions(atoms);

   await supabase.from('clip_entities').insert(
     entityMentions.map(m => ({
       clip_id: clipId,
       entity_id: m.entityId,
       role: m.role,
       mention_count: m.count,
       first_appearance_seconds: m.firstAppearance
     }))
   );
   ```

**Acceptance Criteria:**
- [ ] Atomization fetches entities before processing
- [ ] Gemini receives entity context in prompt
- [ ] Atoms include subject_entity_id and object_entity_id
- [ ] clip_entities table populated after atomization
- [ ] Processing completes without errors

### Phase 4: Face Detection & Clustering (Priority: MEDIUM)
**Estimated: 2 weeks**

Implement facial recognition system:

**New Edge Functions:**
```
supabase/functions/detect-faces/index.ts
supabase/functions/cluster-faces/index.ts
```

**Technology Stack:**
- **Face Detection:** MediaPipe Face Detection or face-api.js
- **Face Recognition:** InsightFace ArcFace (512d embeddings)
- **Clustering:** DBSCAN or hierarchical clustering

**Process Flow:**
1. Extract frames from video (every 1 second)
2. Detect faces in each frame → bounding boxes
3. Generate 512d embeddings for each face
4. Cluster faces by embedding similarity (>0.6 = same person)
5. Check if clusters match existing labeled clusters
6. Auto-assign entity_id if match found
7. Store in face_detections table

**Acceptance Criteria:**
- [ ] Face detection runs automatically after video upload
- [ ] Faces clustered by unique individual
- [ ] Face embeddings stored in database
- [ ] Thumbnails generated for each unique face
- [ ] Auto-matching works for previously labeled faces

### Phase 5: Face Labeling UI (Priority: MEDIUM)
**Estimated: 1 week**

Build user interface for labeling detected faces:

**New Components:**
```
src/components/faces/
  FaceLabelingModal.tsx           - Modal to label faces
  FaceTimeline.tsx                - Visual timeline of faces
  AutoLabelingBanner.tsx          - Shows auto-labeling results
```

**Key Features:**
- Modal appears after video processing if unlabeled faces detected
- Grid of face thumbnails with appearance counts
- Dropdown to select existing entity or create new
- "Skip" option for faces user doesn't want to label
- Auto-labeling notification for recognized faces

**Acceptance Criteria:**
- [ ] Modal opens automatically for clips with unlabeled faces
- [ ] Users can select existing entity from dropdown
- [ ] "Create New" opens entity creation modal
- [ ] Face labels save to face_clusters and face_detections tables
- [ ] Labeled faces appear in entity detail views

### Phase 6: Atom-Face Integration (Priority: MEDIUM)
**Estimated: 1 week**

Enrich atoms with face detection data:

**New Edge Function:**
```
supabase/functions/enrich-atoms-with-faces/index.ts
```

**Process:**
1. For each atom, calculate time range from word indices
2. Query face_detections where timestamp falls in atom range
3. Add `visible_entities` array to atom:
   ```typescript
   {
     // ... existing atom fields
     visible_entities: [
       {
         entity_id: "uuid",
         entity_name: "Kara Smith",
         entity_type: "PERSON",
         source: "face_detection",
         confidence: 0.95,
         appearance_count: 3
       }
     ]
   }
   ```
4. Update clips.atoms_data JSONB

**Acceptance Criteria:**
- [ ] Atoms enriched with visible_entities after face labeling
- [ ] Atom inspector shows both audio and visual entities
- [ ] Entity chips display source badges (🎧 audio, 📹 video)
- [ ] Face timeline shows when each person appears

### Phase 7: Enhanced Search (Priority: LOW)
**Estimated: 1 week**

Add entity-based search capabilities:

**Modifications:**
```
src/services/atomSearch.ts
src/components/search/SearchFilters.tsx
```

**New Features:**
- Entity dropdown filter
- Entity source filter (audio/visual/both)
- "Find clips with person X" searches
- Entity autocomplete in search bar

**Acceptance Criteria:**
- [ ] Users can filter clips by entity
- [ ] Search distinguishes audio vs visual entities
- [ ] Entity detail page links to search results
- [ ] Search performance acceptable (<2s response)

## Technical Specifications

### Database Schema
- **File:** `entity-system-migration.sql`
- **Tables:** entities, clip_entities, face_detections, face_clusters
- **Indices:** GIN for text search, IVFFlat for vector similarity
- **Constraints:** Type checks, foreign keys, unique constraints

### Entity-Aware Atomization
- **File:** `entity-aware-atomization-spec.md`
- **Edge Function:** Modify existing process-video atomization
- **Changes:** Fetch entities, include in prompt, store references

### Facial Recognition
- **File:** `facial-recognition-entity-labeling-spec.md`
- **Technology:** MediaPipe/InsightFace for detection, pgvector for matching
- **Storage:** 512d embeddings, normalized bounding boxes, thumbnails

### Face-Atom Integration
- **File:** `face-labeling-atom-integration-spec.md`
- **Process:** Spatial-temporal matching, atom enrichment, auto-labeling

### UI Components
- **File:** `entity-ui-components-spec.md`
- **Framework:** React + shadcn/ui components
- **Styling:** Tailwind CSS with entity type colors

## Development Guidelines

### Code Style
- Use TypeScript for all new code
- Follow existing Lovable conventions
- Use shadcn/ui components for consistency
- Implement proper error handling and loading states

### Database Migrations
- Create new migration files in `supabase/migrations/`
- Use descriptive names with timestamps
- Include rollback scripts in comments
- Test migrations on staging before production

### Edge Functions
- Keep functions focused and single-purpose
- Implement proper timeout handling
- Add comprehensive logging for debugging
- Use environment variables for configuration

### Testing
- Test entity CRUD operations thoroughly
- Verify face detection with sample videos
- Test auto-matching with known faces
- Validate search performance with large datasets

## Success Metrics

### Functional Requirements
- [ ] Users can create and manage entities
- [ ] Entities appear in atomization context
- [ ] Face detection identifies unique individuals
- [ ] Users can label detected faces
- [ ] Labeled faces link to entities
- [ ] Atoms show both audio and visual entities
- [ ] Search filters work by entity

### Performance Requirements
- [ ] Entity-aware atomization adds <2s per clip
- [ ] Face detection processes 1 min video in <30s
- [ ] Search returns results in <2s
- [ ] UI remains responsive during processing

### User Experience
- [ ] Entity creation is intuitive (no training needed)
- [ ] Face labeling requires <30s per face
- [ ] Entity chips are visually distinct by type
- [ ] Auto-labeling reduces manual work by 70%+

## Implementation Order

**Week 1-2: Foundation**
1. Create database migration
2. Deploy schema changes
3. Test entity CRUD operations
4. Build entity management UI

**Week 3-4: Entity-Aware Processing**
5. Modify atomization Edge Function
6. Test entity linking in atoms
7. Update clip_entities table
8. Verify search integration

**Week 5-6: Face Detection**
9. Implement face detection Edge Function
10. Build clustering algorithm
11. Test auto-matching logic
12. Generate face thumbnails

**Week 7-8: Face Labeling UI**
13. Create face labeling modal
14. Implement entity selection
15. Build face timeline component
16. Test atom enrichment

**Week 9-10: Polish & Optimization**
17. Enhance search with entity filters
18. Add entity detail pages
19. Optimize database queries
20. Performance testing and tuning

## Support Files

All detailed specifications are in the following files:

1. **Entity-System-Implementation-Plan.docx** - High-level overview and architecture
2. **entity-system-migration.sql** - Database schema with all tables and indices
3. **entity-aware-atomization-spec.md** - Atomization modifications and code examples
4. **facial-recognition-entity-labeling-spec.md** - Face detection and clustering system
5. **face-labeling-atom-integration-spec.md** - Atom enrichment and search integration
6. **entity-ui-components-spec.md** - Complete UI component specifications

## Questions for Lovable

Before starting implementation, please confirm:

1. **Database Approach:** Are you comfortable creating Supabase migrations directly, or would you prefer step-by-step guidance?

2. **Face Detection Technology:** Would you prefer:
   - face-api.js (JavaScript, easier to integrate)
   - InsightFace via Python Edge Function (more accurate)
   - Start with face-api.js, upgrade if needed?

3. **Implementation Priority:** Should we:
   - Focus on entity system first (Phases 1-3), then add facial recognition later?
   - Implement facial recognition in parallel?
   - Start with a minimal MVP and expand?

4. **Existing Architecture:** Please confirm:
   - Current atomization Edge Function location
   - How atoms_data JSONB is currently structured
   - Existing search implementation approach

## Next Steps

1. Review all specification documents
2. Ask clarifying questions
3. Start with Phase 1 (Database Foundation)
4. Implement phases sequentially with testing between each
5. Request feedback at the end of each phase

---

**Ready to begin? Start with Phase 1: Database Foundation**

Create the migration file:
```bash
supabase/migrations/[timestamp]_entity_system.sql
```

Copy the schema from `entity-system-migration.sql` and let me know when ready to test!
