# Phase 1: Database Foundation

**Priority:** HIGH | **Duration:** 1-2 hours setup, 1 week completion | **Start Here ⭐**

## Overview

Set up the entity system database schema in Supabase. This is the foundation for all other phases.

## What's Included

- [`entity-system-migration.sql`](./entity-system-migration.sql) - Complete database schema

## What You'll Create

### Tables
- **entities** - Core entity records (PERSON, LOCATION, OBJECT, CONCEPT)
- **clip_entities** - Junction table linking clips to entities
- **face_detections** - Individual face detections with embeddings
- **face_clusters** - Groups of faces representing unique individuals

### Features
- pgvector similarity search
- Full-text search indices
- Helper functions (get_clip_entities, find_similar_entities)
- Row Level Security policies

## Quick Start

1. Create migration file: `supabase/migrations/$(date +%Y%m%d%H%M%S)_entity_system.sql`
2. Copy contents of `entity-system-migration.sql`
3. Apply migration: `supabase db push`
4. Test with sample entities

**Detailed guide:** See [`../../QUICK-START-GUIDE.md`](../../QUICK-START-GUIDE.md)

## Acceptance Criteria

- [ ] All 4 tables created successfully
- [ ] pgvector extension enabled
- [ ] Sample entities inserted and queryable
- [ ] Helper functions work
- [ ] RLS policies configured

## Next Phase

After completing Phase 1, move to [Phase 2: Entity Management UI](../phase-2-entity-ui/)
