-- Entity System Migration for Creative Edit Suite (Lovable)
-- Adds knowledge graph capabilities with entities, clip_entities, and vector embeddings
--
-- Prerequisites:
--   - pgvector extension must be installed (CREATE EXTENSION IF NOT EXISTS vector;)
--   - pg_trgm extension must be installed (CREATE EXTENSION IF NOT EXISTS pg_trgm;)
--
-- Migration date: 2026-02-05

-- ==================================================
-- EXTENSIONS
-- ==================================================

-- Enable vector similarity search (for entity embeddings)
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable fuzzy text search (for entity name matching)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ==================================================
-- ENTITIES TABLE
-- The core knowledge graph nodes: people, places, objects, concepts
-- ==================================================

CREATE TABLE entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Entity identification
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('PERSON', 'LOCATION', 'OBJECT', 'CONCEPT')),
    description TEXT,
    aliases TEXT[] DEFAULT '{}', -- Alternate names/spellings
    attributes JSONB DEFAULT '{}', -- Flexible metadata: {"role": "host", "traits": ["funny"]}

    -- Timeline tracking
    first_seen_clip_id UUID, -- References clips(id), added after clips table modification

    -- Vector embedding for fuzzy matching (OpenAI text-embedding-3-small = 1536 dimensions)
    embedding vector(1536),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure unique entity per name/type combination
    UNIQUE(name, type)
);

-- Performance indices
CREATE INDEX idx_entities_name ON entities USING gin(name gin_trgm_ops); -- Fuzzy name search
CREATE INDEX idx_entities_type ON entities(type); -- Filter by type
CREATE INDEX idx_entities_embedding ON entities USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100); -- Vector similarity

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_entities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entities_update_timestamp
BEFORE UPDATE ON entities
FOR EACH ROW
EXECUTE FUNCTION update_entities_updated_at();

COMMENT ON TABLE entities IS 'Knowledge graph entities: people, locations, objects, concepts mentioned across clips';
COMMENT ON COLUMN entities.embedding IS 'OpenAI embedding vector (1536d) for fuzzy entity matching via cosine similarity';
COMMENT ON COLUMN entities.aliases IS 'Alternative names/spellings for entity (e.g., ["Bob", "Robert", "Rob"] for "Robert Smith")';
COMMENT ON COLUMN entities.first_seen_clip_id IS 'First clip where this entity appeared (for timeline features)';

-- ==================================================
-- CLIP_ENTITIES JUNCTION TABLE
-- Links clips to entities with context (role, appearance time, mentions)
-- ==================================================

CREATE TABLE clip_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relations
    clip_id UUID REFERENCES clips(id) ON DELETE CASCADE NOT NULL,
    entity_id UUID REFERENCES entities(id) ON DELETE CASCADE NOT NULL,

    -- Context metadata
    role TEXT, -- e.g., "host", "guest", "location", "topic", "subject"
    first_appearance_seconds FLOAT, -- When entity first appears in this clip
    mention_count INTEGER DEFAULT 1, -- How many times entity is mentioned
    confidence FLOAT DEFAULT 1.0 CHECK (confidence >= 0.0 AND confidence <= 1.0), -- AI confidence (0-1)

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure one record per clip-entity pair
    UNIQUE(clip_id, entity_id)
);

-- Performance indices
CREATE INDEX idx_clip_entities_clip ON clip_entities(clip_id); -- Query by clip
CREATE INDEX idx_clip_entities_entity ON clip_entities(entity_id); -- Query by entity
CREATE INDEX idx_clip_entities_role ON clip_entities(role); -- Filter by role

COMMENT ON TABLE clip_entities IS 'Junction table linking clips to entities with role and mention metadata';
COMMENT ON COLUMN clip_entities.confidence IS 'AI confidence score for entity identification (0.0-1.0, higher = more confident)';
COMMENT ON COLUMN clip_entities.mention_count IS 'Number of times entity is mentioned/referenced in the clip';

-- ==================================================
-- MODIFY EXISTING CLIPS TABLE
-- Add foreign key for entity system timeline tracking
-- ==================================================

-- Add foreign key constraint for entity timeline
ALTER TABLE entities
ADD CONSTRAINT fk_entities_first_seen_clip
FOREIGN KEY (first_seen_clip_id) REFERENCES clips(id) ON DELETE SET NULL;

COMMENT ON COLUMN entities.first_seen_clip_id IS 'Foreign key to clips(id) - tracks when entity first appeared';

-- ==================================================
-- ENHANCED ATOMS_DATA JSONB SCHEMA
-- Document the expected structure for atoms with entity references
-- ==================================================

-- NOTE: No schema changes needed - clips.atoms_data already exists as JSONB
-- This section documents the enhanced schema structure that will be written by the atomization Edge Function

COMMENT ON COLUMN clips.atoms_data IS
'JSONB array of atoms with structure:
[{
  "start_word_index": 142,
  "end_word_index": 158,
  "subject_entity_id": "uuid", // NEW: References entities(id)
  "subject_text": "Kara", // Fallback if no entity match
  "action": "Hesitates to eat",
  "object_text": "live octopus tentacle",
  "object_entity_id": "uuid", // NEW: References entities(id)
  "thought_signature": "Social pressure vs internal disgust",
  "visual_cue_prediction": "Hand trembling, forced smile",
  "emotion": "fear",
  "emotional_valence": "negative",
  "emotion_intensity": 0.8,
  "transcript_excerpt": "Okay, here goes nothing... yum!",
  "search_keywords": ["fear", "hesitation", "trying new food"]
}]';

-- ==================================================
-- HELPER FUNCTIONS
-- ==================================================

-- Function to find similar entities by vector similarity
-- Usage: SELECT * FROM find_similar_entities('John Smith', 0.85, 5);
CREATE OR REPLACE FUNCTION find_similar_entities(
    query_text TEXT,
    similarity_threshold FLOAT DEFAULT 0.85,
    max_results INTEGER DEFAULT 10
)
RETURNS TABLE (
    entity_id UUID,
    entity_name TEXT,
    entity_type TEXT,
    similarity_score FLOAT
) AS $$
BEGIN
    -- NOTE: This function requires an embedding to be passed in
    -- In practice, you'd generate the embedding via OpenAI API first
    -- Example usage in Edge Function:
    -- 1. Generate embedding: const embedding = await openai.embeddings.create({input: query_text})
    -- 2. Query: SELECT * FROM entities WHERE embedding <=> embedding_vector < (1 - similarity_threshold) ORDER BY embedding <=> embedding_vector LIMIT max_results;

    RETURN QUERY
    SELECT
        e.id,
        e.name,
        e.type,
        1.0::FLOAT -- Placeholder - actual similarity calculated via <=> operator with embedding vector
    FROM entities e
    WHERE e.name ILIKE '%' || query_text || '%' -- Fallback fuzzy text match
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_similar_entities IS
'Find entities similar to query text using vector similarity.
NOTE: Requires OpenAI embedding generation in application layer.
Use pgvector <=> operator with embedding vector for actual similarity calculation.';

-- Function to get all entities for a clip
CREATE OR REPLACE FUNCTION get_clip_entities(clip_uuid UUID)
RETURNS TABLE (
    entity_id UUID,
    entity_name TEXT,
    entity_type TEXT,
    role TEXT,
    mention_count INTEGER,
    confidence FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.name,
        e.type,
        ce.role,
        ce.mention_count,
        ce.confidence
    FROM entities e
    JOIN clip_entities ce ON ce.entity_id = e.id
    WHERE ce.clip_id = clip_uuid
    ORDER BY ce.mention_count DESC, e.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_clip_entities IS 'Get all entities mentioned in a clip with their roles and mention counts';

-- Function to get all clips for an entity
CREATE OR REPLACE FUNCTION get_entity_clips(entity_uuid UUID)
RETURNS TABLE (
    clip_id UUID,
    clip_name TEXT,
    role TEXT,
    first_appearance_seconds FLOAT,
    mention_count INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        ce.role,
        ce.first_appearance_seconds,
        ce.mention_count,
        c.created_at
    FROM clips c
    JOIN clip_entities ce ON ce.clip_id = c.id
    WHERE ce.entity_id = entity_uuid
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_entity_clips IS 'Get all clips where an entity appears with timeline metadata';

-- ==================================================
-- SAMPLE DATA (Optional - for testing)
-- ==================================================

-- Uncomment to insert sample entities for testing

-- INSERT INTO entities (name, type, description, aliases) VALUES
--     ('Kara', 'PERSON', 'Host of travel show, adventurous eater', ARRAY['Kara Smith']),
--     ('Nate', 'PERSON', 'Co-host, cautious about food', ARRAY['Nathan', 'Nate Jones']),
--     ('Seoul', 'LOCATION', 'Capital of South Korea', ARRAY['Seoul City', 'Seoul, Korea']),
--     ('Gwangjang Market', 'LOCATION', 'Famous street food market in Seoul', ARRAY['Gwangjang Traditional Market']),
--     ('Live Octopus', 'OBJECT', 'Sannakji - moving octopus tentacles', ARRAY['Sannakji', 'Octopus Tentacles']);

-- ==================================================
-- ROLLBACK SCRIPT (Run if migration needs to be reverted)
-- ==================================================

-- DROP FUNCTION IF EXISTS get_entity_clips(UUID);
-- DROP FUNCTION IF EXISTS get_clip_entities(UUID);
-- DROP FUNCTION IF EXISTS find_similar_entities(TEXT, FLOAT, INTEGER);
-- ALTER TABLE entities DROP CONSTRAINT IF EXISTS fk_entities_first_seen_clip;
-- DROP INDEX IF EXISTS idx_clip_entities_role;
-- DROP INDEX IF EXISTS idx_clip_entities_entity;
-- DROP INDEX IF EXISTS idx_clip_entities_clip;
-- DROP TABLE IF EXISTS clip_entities;
-- DROP TRIGGER IF EXISTS entities_update_timestamp ON entities;
-- DROP FUNCTION IF EXISTS update_entities_updated_at();
-- DROP INDEX IF EXISTS idx_entities_embedding;
-- DROP INDEX IF EXISTS idx_entities_type;
-- DROP INDEX IF EXISTS idx_entities_name;
-- DROP TABLE IF EXISTS entities;

-- ==================================================
-- POST-MIGRATION CHECKLIST
-- ==================================================

-- [ ] Verify extensions installed: SELECT * FROM pg_extension WHERE extname IN ('vector', 'pg_trgm');
-- [ ] Verify tables created: \dt entities clip_entities
-- [ ] Verify indices created: \di idx_entities_*
-- [ ] Test entity CRUD operations
-- [ ] Test vector similarity search (requires embedding generation)
-- [ ] Update Edge Functions to use new entity tables
-- [ ] Update UI components to display entity information
-- [ ] Re-process existing clips with entity-aware atomization (background job)
