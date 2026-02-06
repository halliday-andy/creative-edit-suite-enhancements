# Quick Start Guide - Phase 1: Database Foundation

## Goal
Set up the entity system database schema in Supabase so you can start creating and managing entities.

**Time Required:** 1-2 hours
**Prerequisites:** Supabase project set up, database access

## Step-by-Step Instructions

### Step 1: Create Migration File (5 minutes)

1. Navigate to your Creative Edit Suite project
2. Create a new migration file:

```bash
cd supabase/migrations
touch $(date +%Y%m%d%H%M%S)_entity_system.sql
```

Or manually create:
```
supabase/migrations/20260206120000_entity_system.sql
```

### Step 2: Copy Database Schema (2 minutes)

1. Open the file `entity-system-migration.sql` from this package
2. Copy the **entire contents**
3. Paste into your new migration file

The schema includes:
- ✅ pgvector extension for similarity search
- ✅ entities table (4 types: PERSON, LOCATION, OBJECT, CONCEPT)
- ✅ clip_entities junction table
- ✅ face_detections table (for facial recognition)
- ✅ face_clusters table (groups faces by person)
- ✅ All necessary indices for performance
- ✅ Helper functions

### Step 3: Apply Migration (5 minutes)

**If using Supabase CLI:**
```bash
supabase db push
```

**If using Supabase Studio (web interface):**
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Create a new query
4. Paste the migration SQL
5. Click **Run**

**Verify migration succeeded:**
```sql
-- Check that tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('entities', 'clip_entities', 'face_detections', 'face_clusters');

-- Should return 4 rows
```

### Step 4: Verify pgvector Extension (2 minutes)

Check that pgvector is enabled:

```sql
SELECT * FROM pg_extension WHERE extname = 'vector';
```

If not enabled, run:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### Step 5: Test with Sample Data (10 minutes)

Insert test entities:

```sql
-- Create sample entities
INSERT INTO entities (name, type, description, aliases) VALUES
  ('Kara Smith', 'PERSON', 'Host of travel show, adventurous eater', ARRAY['Kara', 'K. Smith']),
  ('Nate Johnson', 'PERSON', 'Co-host, cautious about food', ARRAY['Nate', 'Nathan']),
  ('Seoul', 'LOCATION', 'Capital of South Korea', ARRAY['Seoul City', 'Seoul, Korea']),
  ('Gwangjang Market', 'LOCATION', 'Famous street food market in Seoul', ARRAY['Gwangjang Traditional Market']),
  ('Live Octopus', 'OBJECT', 'Sannakji - moving octopus tentacles', ARRAY['Sannakji', 'Octopus Tentacles']);

-- Verify insertion
SELECT id, name, type FROM entities ORDER BY name;
```

**Expected output:**
```
id                                   | name              | type
-------------------------------------|-------------------|----------
[uuid]                               | Gwangjang Market  | LOCATION
[uuid]                               | Kara Smith        | PERSON
[uuid]                               | Live Octopus      | OBJECT
[uuid]                               | Nate Johnson      | PERSON
[uuid]                               | Seoul             | LOCATION
```

### Step 6: Test Entity Queries (10 minutes)

**Test 1: Find entities by type**
```sql
SELECT name, type, description
FROM entities
WHERE type = 'PERSON';
```

**Test 2: Search by name (fuzzy)**
```sql
SELECT name, type, aliases
FROM entities
WHERE name ILIKE '%kara%' OR 'kara' = ANY(aliases);
```

**Test 3: Test helper function**
```sql
SELECT * FROM get_clip_entities('00000000-0000-0000-0000-000000000000');
-- Should return empty (no clips yet)
```

### Step 7: Configure Row Level Security (5 minutes)

Since Lovable is a single-user demo, allow all operations:

```sql
-- Enable RLS on new tables
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE clip_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_clusters ENABLE ROW LEVEL SECURITY;

-- Create permissive policies (anyone can do anything)
CREATE POLICY "Allow all operations on entities" ON entities FOR ALL USING (true);
CREATE POLICY "Allow all operations on clip_entities" ON clip_entities FOR ALL USING (true);
CREATE POLICY "Allow all operations on face_detections" ON face_detections FOR ALL USING (true);
CREATE POLICY "Allow all operations on face_clusters" ON face_clusters FOR ALL USING (true);
```

### Step 8: Update TypeScript Types (15 minutes)

Add entity types to your TypeScript definitions:

**File:** `src/types/database.ts` (or similar)

```typescript
export interface Entity {
  id: string;
  name: string;
  type: 'PERSON' | 'LOCATION' | 'OBJECT' | 'CONCEPT';
  description?: string;
  aliases: string[];
  attributes: Record<string, any>;
  first_seen_clip_id?: string;
  embedding?: number[];
  created_at: string;
  updated_at: string;
}

export interface ClipEntity {
  id: string;
  clip_id: string;
  entity_id: string;
  role?: string;
  first_appearance_seconds?: number;
  mention_count: number;
  confidence: number;
  created_at: string;
}

export interface FaceDetection {
  id: string;
  clip_id: string;
  timestamp_seconds: number;
  bbox_x: number;
  bbox_y: number;
  bbox_width: number;
  bbox_height: number;
  face_embedding?: number[];
  face_cluster_id?: string;
  entity_id?: string;
  thumbnail_path?: string;
  confidence: number;
  created_at: string;
}

export interface FaceCluster {
  id: string;
  representative_detection_id?: string;
  entity_id?: string;
  is_labeled: boolean;
  labeled_by_user: boolean;
  total_detections: number;
  avg_confidence?: number;
  created_at: string;
  updated_at: string;
}
```

### Step 9: Create Basic Entity Service (20 minutes)

**File:** `src/services/entityService.ts`

```typescript
import { supabase } from '@/lib/supabase';
import type { Entity } from '@/types/database';

export const entityService = {
  // Get all entities
  async getAll(): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .order('name');

    if (error) throw error;
    return data || [];
  },

  // Get entities by type
  async getByType(type: Entity['type']): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .eq('type', type)
      .order('name');

    if (error) throw error;
    return data || [];
  },

  // Get single entity
  async getById(id: string): Promise<Entity | null> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;
    return data;
  },

  // Create entity
  async create(entity: Omit<Entity, 'id' | 'created_at' | 'updated_at'>): Promise<Entity> {
    const { data, error } = await supabase
      .from('entities')
      .insert(entity)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Update entity
  async update(id: string, updates: Partial<Entity>): Promise<Entity> {
    const { data, error } = await supabase
      .from('entities')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  // Delete entity
  async delete(id: string): Promise<void> {
    const { error } = await supabase
      .from('entities')
      .delete()
      .eq('id', id);

    if (error) throw error;
  },

  // Search entities
  async search(query: string): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .or(`name.ilike.%${query}%,description.ilike.%${query}%`)
      .order('name');

    if (error) throw error;
    return data || [];
  }
};
```

### Step 10: Test Entity Service (10 minutes)

Create a test file or use browser console:

```typescript
// Test create
const newEntity = await entityService.create({
  name: 'Test Person',
  type: 'PERSON',
  description: 'A test person',
  aliases: ['Test', 'TP'],
  attributes: {}
});

console.log('Created:', newEntity);

// Test getAll
const allEntities = await entityService.getAll();
console.log('All entities:', allEntities);

// Test search
const results = await entityService.search('test');
console.log('Search results:', results);

// Test delete
await entityService.delete(newEntity.id);
console.log('Deleted test entity');
```

## ✅ Verification Checklist

Check that everything is working:

- [ ] Migration file created and applied
- [ ] pgvector extension enabled
- [ ] All 4 tables exist (entities, clip_entities, face_detections, face_clusters)
- [ ] Indices created (check with `\di` in psql or Supabase Studio)
- [ ] Sample entities inserted successfully
- [ ] Entity queries return expected results
- [ ] Helper functions work
- [ ] RLS policies configured
- [ ] TypeScript types added
- [ ] Entity service created and tested
- [ ] No errors in Supabase logs

## 🎉 Success!

You've completed Phase 1! You now have:
- ✅ Complete database schema for entity system
- ✅ Sample entities to work with
- ✅ TypeScript types for type safety
- ✅ Basic entity service for CRUD operations

## 🔜 Next Steps

### Move to Phase 2: Entity Management UI

You're ready to build the user interface! Open `entity-ui-components-spec.md` and start with:

1. Create `/src/pages/Entities.tsx` page
2. Build `EntityList` component
3. Create `EntityCard` component
4. Implement `CreateEntityModal`

**See:** `entity-ui-components-spec.md` for detailed component specifications

### Or Move to Phase 3: Entity-Aware Atomization

If you want to see entities in action first, jump to processing:

1. Modify atomization Edge Function
2. Add entity fetching before processing
3. Include entities in Gemini prompt
4. Store entity references in atoms

**See:** `entity-aware-atomization-spec.md` for implementation guide

## 🐛 Troubleshooting

### Error: "extension 'vector' does not exist"

**Solution:**
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

If that fails, you may need to enable it in Supabase Studio:
1. Go to Database → Extensions
2. Find "vector" in the list
3. Click "Enable"

### Error: "permission denied for schema public"

**Solution:** Check that RLS policies are created. Run the policies from Step 7.

### Error: "column 'embedding' does not exist"

**Solution:** The migration didn't apply fully. Re-run the migration SQL in SQL Editor.

### Entities not appearing in UI

**Solution:**
1. Check browser console for errors
2. Verify Supabase connection in network tab
3. Test entity service in console: `await entityService.getAll()`
4. Check RLS policies are permissive

## 📚 Additional Resources

- **Full database schema:** `entity-system-migration.sql`
- **Implementation roadmap:** `LOVABLE-IMPLEMENTATION-PROMPT.md`
- **UI components:** `entity-ui-components-spec.md`
- **Processing pipeline:** `entity-aware-atomization-spec.md`

---

**Questions?** Review the relevant spec document or check the main implementation prompt for guidance.

**Ready for Phase 2?** Open `entity-ui-components-spec.md` to start building the UI!
