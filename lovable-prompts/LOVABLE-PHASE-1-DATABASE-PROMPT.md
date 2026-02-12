# Phase 1: Database Foundation - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 1 of 7
**Duration:** 1-2 weeks
**Priority:** HIGH (Blocks all other phases)

---

## 🎯 Objective

Implement the database foundation for the entity and facial recognition system. This phase creates 4 new tables that will store entities (people, locations, objects, concepts), their relationships to clips, face detection data, and person clusters.

**This is pure database work - no UI components in this phase.**

---

## 📋 What to Build

### 1. Create Migration File

**File:** `/supabase/migrations/YYYYMMDD_entity_system_foundation.sql`

Copy the complete SQL from the attached `entity-system-migration.sql` document.

### 2. Tables to Create (4 total)

#### Table 1: `entities`
Stores knowledge graph entities (people, locations, objects, concepts).

**Key Features:**
- Supports 4 entity types: PERSON, LOCATION, OBJECT, CONCEPT
- 1536-dimensional vector embeddings for semantic search (pgvector)
- Metadata JSONB for flexible additional data
- Full-text search support

#### Table 2: `clip_entities`
Links entities to clips with relationship type and confidence.

**Key Features:**
- Many-to-many relationship between clips and entities
- Relationship types: subject, location, mentioned, visible, related
- Confidence scores (0-1)
- Context snippets for why entity is linked

#### Table 3: `face_detections`
Stores individual face detection results from video frames.

**Key Features:**
- Normalized bounding box coordinates (0-1)
- 512-dimensional face embeddings (pgvector)
- Links to clips and optional entity associations
- Confidence scores and thumbnail paths

#### Table 4: `face_clusters`
Groups face detections by unique individual.

**Key Features:**
- Cluster key for grouping faces
- Representative face selection
- Appearance count tracking
- Links to person entities when labeled

---

## 🔧 Technical Requirements

### Prerequisites

1. **pgvector Extension**
   - Must be enabled in Supabase
   - Required for vector similarity search
   - Check: `CREATE EXTENSION IF NOT EXISTS vector;`

2. **Database Access**
   - Supabase project with admin access
   - SQL Editor access for running migrations

### Vector Dimensions

- **Entity embeddings:** 1536 dimensions (OpenAI text-embedding-3-small)
- **Face embeddings:** 512 dimensions (InsightFace ArcFace or face-api.js)

### Indexes

The migration includes optimized indexes for:
- Entity name search
- Entity type filtering
- Clip-entity lookups
- Face detection spatial queries
- Vector similarity search (HNSW indexes)

---

## 📝 Step-by-Step Instructions

### Step 1: Enable pgvector Extension

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

**Verification:**
```sql
SELECT * FROM pg_extension WHERE extname = 'vector';
```

### Step 2: Run the Migration

1. Open Supabase SQL Editor
2. Copy the complete contents of `entity-system-migration.sql`
3. Execute the migration
4. Verify all 4 tables were created

**Verification:**
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('entities', 'clip_entities', 'face_detections', 'face_clusters');
```

You should see all 4 tables listed.

### Step 3: Test Vector Columns

```sql
-- Test entity embedding column
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'entities'
AND column_name = 'embedding';

-- Test face embedding column
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'face_detections'
AND column_name = 'face_embedding';
```

### Step 4: Verify Indexes

```sql
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('entities', 'clip_entities', 'face_detections', 'face_clusters')
ORDER BY tablename, indexname;
```

You should see multiple indexes per table including HNSW vector indexes.

### Step 5: Test Constraints

```sql
-- Test entity type constraint
INSERT INTO entities (name, type, embedding)
VALUES ('Test', 'INVALID_TYPE', NULL);
-- Should fail with constraint violation

-- Test relationship type constraint
INSERT INTO clip_entities (clip_id, entity_id, relationship_type, confidence)
VALUES (gen_random_uuid(), gen_random_uuid(), 'INVALID', 0.9);
-- Should fail with constraint violation
```

### Step 6: Grant Permissions

```sql
-- Grant access to authenticated users
GRANT ALL ON entities TO authenticated;
GRANT ALL ON clip_entities TO authenticated;
GRANT ALL ON face_detections TO authenticated;
GRANT ALL ON face_clusters TO authenticated;

-- Verify permissions
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name IN ('entities', 'clip_entities', 'face_detections', 'face_clusters');
```

---

## ✅ Acceptance Criteria

### Must Complete All:

- [ ] **pgvector extension enabled** - `CREATE EXTENSION vector` succeeds
- [ ] **All 4 tables created** - entities, clip_entities, face_detections, face_clusters exist
- [ ] **Vector columns work** - Can insert and query vector(1536) and vector(512) columns
- [ ] **Constraints enforced** - Invalid entity types and relationship types are rejected
- [ ] **Indexes created** - All indexes including HNSW vector indexes exist
- [ ] **Foreign keys work** - Can create relationships between tables
- [ ] **Permissions granted** - Authenticated users can read/write all tables
- [ ] **No errors in logs** - Supabase logs show no errors after migration

### Verification Queries

Run these to verify everything works:

```sql
-- 1. Create test entity
INSERT INTO entities (name, type, description, embedding)
VALUES (
  'Test Person',
  'PERSON',
  'A test person entity',
  array_fill(0, ARRAY[1536])::vector(1536)
)
RETURNING id;

-- 2. Create test clip_entity link
INSERT INTO clip_entities (clip_id, entity_id, relationship_type, confidence)
VALUES (
  (SELECT id FROM clips LIMIT 1),
  (SELECT id FROM entities WHERE name = 'Test Person'),
  'subject',
  0.95
);

-- 3. Test vector similarity search
SELECT id, name, type,
       embedding <=> array_fill(0, ARRAY[1536])::vector(1536) AS distance
FROM entities
WHERE embedding IS NOT NULL
ORDER BY distance
LIMIT 5;

-- 4. Clean up test data
DELETE FROM clip_entities WHERE entity_id IN (SELECT id FROM entities WHERE name = 'Test Person');
DELETE FROM entities WHERE name = 'Test Person';
```

---

## 🚫 Common Issues & Solutions

### Issue 1: pgvector Extension Not Available

**Error:** `extension "vector" does not exist`

**Solution:**
- Go to Supabase Dashboard → Database → Extensions
- Find "vector" in the list
- Click "Enable"
- Wait 1-2 minutes for activation
- Retry migration

### Issue 2: Vector Dimension Mismatch

**Error:** `expected 1536 dimensions, not X`

**Solution:**
- Ensure you're using the correct dimensions
- Entities: 1536 (OpenAI text-embedding-3-small)
- Faces: 512 (InsightFace/face-api.js)

### Issue 3: Foreign Key Constraint Fails

**Error:** `violates foreign key constraint`

**Solution:**
- Ensure referenced tables exist (clips, users)
- Check that UUIDs are valid
- Verify clips table has rows for testing

### Issue 4: Permission Denied

**Error:** `permission denied for table entities`

**Solution:**
- Run the GRANT statements from Step 6
- Verify you're authenticated as the correct user
- Check Row Level Security (RLS) policies

---

## 📚 Reference Documents

### Included in This Package:

1. **entity-system-migration.sql** - Complete SQL migration (copy-paste ready)
2. **Entity-System-Implementation-Plan.docx** - Full context and specifications

### Where to Find:

These documents are in the `creative-edit-suite-enhancements` repository:
- `phase-1-database/entity-system-migration.sql`
- `docs/Entity-System-Implementation-Plan.docx`

---

## 🔄 Rollback Plan

If you need to undo this migration:

```sql
-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS clip_entities CASCADE;
DROP TABLE IF EXISTS face_clusters CASCADE;
DROP TABLE IF EXISTS face_detections CASCADE;
DROP TABLE IF EXISTS entities CASCADE;

-- Note: This will delete all data in these tables
-- Only use for testing/development
```

---

## ⏭️ Next Steps After Completion

Once Phase 1 is complete:

1. ✅ Verify all acceptance criteria
2. ✅ Run all verification queries successfully
3. ✅ Check Supabase logs for any errors
4. ✅ Document any issues encountered
5. ✅ Move to **Phase 2: Entity Management UI**

---

## 💬 Questions to Ask if Stuck

1. **Does pgvector extension show as enabled in Supabase Dashboard?**
2. **Are you using the latest Supabase version?** (pgvector requires recent version)
3. **Do you have admin access to run migrations?**
4. **Are there any errors in the Supabase logs after running migration?**
5. **Can you run a simple `SELECT * FROM entities` query?**

---

## 📞 Support

If you encounter issues:

1. Check Supabase logs (Dashboard → Database → Logs)
2. Verify pgvector version: `SELECT * FROM pg_available_extensions WHERE name = 'vector';`
3. Check table creation: `\dt` in SQL Editor
4. Review foreign key constraints: `\d entities` in psql

---

**Estimated Time:** 2-4 hours (including verification and testing)

**Ready to start?** Open Supabase SQL Editor and begin with Step 1! 🚀

---

**Phase 1 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
**Document Version:** 1.0
