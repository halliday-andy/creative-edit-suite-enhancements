# Phase 2: Entity Management UI - Implementation Prompt for Lovable

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Phase:** 2 of 7
**Duration:** 1 week
**Priority:** HIGH
**Depends On:** Phase 1 (Database Foundation)

---

## 🎯 Objective

Build the Entity Management UI that allows users to create, view, edit, and delete entities (people, locations, objects, concepts). This includes a dedicated Entities page, entity list/grid view, create/edit modals, and entity detail pages.

**This phase focuses on CRUD operations for entities - no face labeling yet.**

---

## 📋 What to Build

### 1. New Page: `/entities`

Create a dedicated Entities page in the app.

**URL:** `/entities`
**Layout:** Full-page with sidebar navigation

### 2. Components to Create (6 new)

1. **EntityList** - Main list/grid view of all entities
2. **EntityCard** - Individual entity card with thumbnail and info
3. **CreateEntityModal** - Modal dialog for creating new entities
4. **EditEntityModal** - Modal dialog for editing existing entities
5. **EntityDetailPage** - Full page showing entity details and related clips
6. **EntityTypeFilter** - Filter dropdown for PERSON/LOCATION/OBJECT/CONCEPT

### 3. Service Layer

Create `/src/services/entityService.ts` with:
- `getAll()` - Fetch all entities
- `getById(id)` - Fetch single entity
- `create(entity)` - Create new entity
- `update(id, updates)` - Update entity
- `delete(id)` - Delete entity
- `search(query)` - Search entities by name
- `getRelatedClips(entityId)` - Get clips linked to entity

---

## 🎨 UI Specifications

### EntityList Component

**Location:** `/src/pages/Entities.tsx` or `/src/components/entities/EntityList.tsx`

**Features:**
- Grid view of entity cards (3-4 per row on desktop)
- Filter by entity type (ALL/PERSON/LOCATION/OBJECT/CONCEPT)
- Search bar for entity names
- "Create Entity" button (top-right)
- Empty state when no entities exist

**Layout:**
```
┌─────────────────────────────────────────┐
│ Entities                    [+ Create]  │
├─────────────────────────────────────────┤
│ [Search...] [Type: All ▾]               │
├─────────────────────────────────────────┤
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │Card 1│ │Card 2│ │Card 3│ │Card 4│   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
│ ┌──────┐ ┌──────┐                      │
│ │Card 5│ │Card 6│                      │
│ └──────┘ └──────┘                      │
└─────────────────────────────────────────┘
```

### EntityCard Component

**Props:**
```typescript
interface EntityCardProps {
  entity: Entity;
  onEdit: () => void;
  onDelete: () => void;
  onClick: () => void;
}
```

**Display:**
- Entity icon (👤 person, 📍 location, 📦 object, 💡 concept)
- Entity name (bold, 16px)
- Entity type badge (small chip)
- Description (truncated, 2 lines max)
- Metadata count (e.g., "5 clips")
- Edit and Delete buttons (on hover)

**Styling:**
- Card with rounded corners
- Shadow on hover
- Cursor pointer
- Click to open detail page

### CreateEntityModal Component

**Trigger:** "Create Entity" button in EntityList

**Form Fields:**
1. **Name** (required, text input)
2. **Type** (required, dropdown: PERSON/LOCATION/OBJECT/CONCEPT)
3. **Description** (optional, textarea)
4. **Aliases** (optional, comma-separated text input)
5. **Metadata** (optional, JSON editor or key-value pairs)

**Actions:**
- "Cancel" button (closes modal)
- "Create" button (saves and closes)

**Validation:**
- Name required (min 2 characters)
- Type required
- Show error messages inline

### EditEntityModal Component

**Similar to CreateEntityModal but:**
- Pre-filled with existing entity data
- "Update" button instead of "Create"
- Can delete entity from this modal

### EntityDetailPage Component

**URL:** `/entities/:id`

**Sections:**
1. **Header:**
   - Entity name (H1)
   - Entity type badge
   - Edit button
   - Delete button (with confirmation)

2. **Info Card:**
   - Description
   - Aliases (if any)
   - Metadata (if any)
   - Created/Updated timestamps

3. **Related Clips Section:**
   - List of clips that mention/show this entity
   - For each clip: thumbnail, title, relationship type, confidence
   - Click clip to navigate to clip detail

**Empty States:**
- "No clips linked to this entity yet"

---

## 🔧 Technical Implementation

### TypeScript Types

Create `/src/types/entity.ts`:

```typescript
export type EntityType = 'PERSON' | 'LOCATION' | 'OBJECT' | 'CONCEPT';

export type RelationshipType = 'subject' | 'location' | 'mentioned' | 'visible' | 'related';

export interface Entity {
  id: string;
  name: string;
  type: EntityType;
  description: string | null;
  aliases: string[];
  metadata: Record<string, any>;
  embedding: number[] | null;
  created_at: string;
  updated_at: string;
}

export interface ClipEntity {
  id: string;
  clip_id: string;
  entity_id: string;
  relationship_type: RelationshipType;
  confidence: number;
  context: string | null;
  created_at: string;
}
```

### Entity Service

Create `/src/services/entityService.ts`:

```typescript
import { supabase } from '@/lib/supabase';
import type { Entity, EntityType } from '@/types/entity';

export const entityService = {
  async getAll(): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .order('name');

    if (error) throw error;
    return data || [];
  },

  async getById(id: string): Promise<Entity | null> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;
    return data;
  },

  async create(entity: Omit<Entity, 'id' | 'created_at' | 'updated_at' | 'embedding'>): Promise<Entity> {
    const { data, error } = await supabase
      .from('entities')
      .insert(entity)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

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

  async delete(id: string): Promise<void> {
    const { error } = await supabase
      .from('entities')
      .delete()
      .eq('id', id);

    if (error) throw error;
  },

  async search(query: string): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .or(`name.ilike.%${query}%,description.ilike.%${query}%`)
      .order('name');

    if (error) throw error;
    return data || [];
  },

  async getByType(type: EntityType): Promise<Entity[]> {
    const { data, error } = await supabase
      .from('entities')
      .select('*')
      .eq('type', type)
      .order('name');

    if (error) throw error;
    return data || [];
  },

  async getRelatedClips(entityId: string) {
    const { data, error } = await supabase
      .from('clip_entities')
      .select(`
        *,
        clip:clips(*)
      `)
      .eq('entity_id', entityId);

    if (error) throw error;
    return data || [];
  },
};
```

### React Hooks

Create `/src/hooks/useEntities.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { entityService } from '@/services/entityService';
import type { Entity, EntityType } from '@/types/entity';

export function useEntities(type?: EntityType) {
  return useQuery({
    queryKey: ['entities', type],
    queryFn: () => type ? entityService.getByType(type) : entityService.getAll(),
  });
}

export function useEntity(id: string) {
  return useQuery({
    queryKey: ['entities', id],
    queryFn: () => entityService.getById(id),
    enabled: !!id,
  });
}

export function useCreateEntity() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: entityService.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['entities'] });
    },
  });
}

export function useUpdateEntity() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, updates }: { id: string; updates: Partial<Entity> }) =>
      entityService.update(id, updates),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['entities'] });
    },
  });
}

export function useDeleteEntity() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: entityService.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['entities'] });
    },
  });
}
```

---

## ✅ Acceptance Criteria

### Must Complete All:

- [ ] **Entities page accessible** - Navigate to `/entities` in app
- [ ] **Empty state displays** - Shows helpful message when no entities
- [ ] **Create entity works** - Can create entities of all 4 types
- [ ] **Entity list displays** - Shows all created entities in grid
- [ ] **Entity cards show info** - Name, type, description, clip count
- [ ] **Filter by type works** - Can filter by PERSON/LOCATION/OBJECT/CONCEPT
- [ ] **Search works** - Can search entities by name
- [ ] **Edit entity works** - Can update entity name, type, description
- [ ] **Delete entity works** - Can delete entity with confirmation
- [ ] **Entity detail page works** - Can view full entity details
- [ ] **Related clips display** - Shows clips linked to entity (if any)
- [ ] **Responsive design** - Works on desktop and mobile
- [ ] **Loading states** - Shows spinners during API calls
- [ ] **Error handling** - Shows error messages on failures

### Test Cases:

1. **Create Person Entity:**
   - Name: "John Doe"
   - Type: PERSON
   - Description: "CEO of Example Corp"
   - Verify appears in list

2. **Create Location Entity:**
   - Name: "San Francisco"
   - Type: LOCATION
   - Description: "City in California"
   - Verify appears in list

3. **Filter Test:**
   - Create 2 PERSON, 2 LOCATION entities
   - Filter by PERSON - should show 2
   - Filter by LOCATION - should show 2
   - Filter by ALL - should show 4

4. **Search Test:**
   - Search "John" - should find "John Doe"
   - Search "San" - should find "San Francisco"
   - Search "xyz" - should show empty state

5. **Edit Test:**
   - Edit "John Doe" → "Jane Doe"
   - Verify name updated in list
   - Verify name updated in detail page

6. **Delete Test:**
   - Delete "Jane Doe"
   - Confirm deletion dialog appears
   - Verify entity removed from list

---

## 🎨 UI Component Library

Use existing shadcn/ui components:
- `Card` - for EntityCard
- `Dialog` - for CreateEntityModal, EditEntityModal
- `Input` - for form fields
- `Textarea` - for description
- `Select` - for entity type dropdown
- `Button` - for actions
- `Badge` - for type indicators
- `AlertDialog` - for delete confirmation

---

## 📁 File Structure

```
src/
├── pages/
│   └── Entities.tsx                  # Main entities page
├── components/
│   └── entities/
│       ├── EntityList.tsx            # List/grid view
│       ├── EntityCard.tsx            # Individual card
│       ├── CreateEntityModal.tsx     # Create dialog
│       ├── EditEntityModal.tsx       # Edit dialog
│       ├── EntityDetailPage.tsx      # Detail view
│       └── EntityTypeFilter.tsx      # Type filter
├── services/
│   └── entityService.ts              # API service
├── hooks/
│   └── useEntities.ts                # React Query hooks
└── types/
    └── entity.ts                     # TypeScript types
```

---

## 🚫 Common Issues & Solutions

### Issue 1: Entities Not Loading

**Symptom:** Empty list even after creating entities

**Solution:**
- Check Supabase RLS policies allow reads
- Check browser console for errors
- Verify query is fetching from correct table

### Issue 2: Create Fails with "permission denied"

**Symptom:** Error when trying to create entity

**Solution:**
- Check Supabase RLS policies allow inserts
- Verify user is authenticated
- Check required fields are provided

### Issue 3: Types Don't Match

**Symptom:** TypeScript errors about entity types

**Solution:**
- Ensure `EntityType` matches database constraint
- Use exact strings: 'PERSON', 'LOCATION', 'OBJECT', 'CONCEPT'

---

## 📚 Reference Documents

1. **entity-ui-components-spec.md** - Detailed component specifications
2. **LOVABLE-IMPLEMENTATION-PROMPT.md** - Phase 2 section

---

## ⏭️ Next Steps After Completion

Once Phase 2 is complete:

1. ✅ Test all CRUD operations
2. ✅ Verify responsive design on mobile
3. ✅ Check error handling for edge cases
4. ✅ Screenshot the UI for documentation
5. ✅ Move to **Phase 3: Entity-Aware Atomization**

---

**Estimated Time:** 1 week (8-12 hours of development)

**Ready to build?** Start with the Entity service, then build components! 🚀

---

**Phase 2 Status:** 🔴 Not Started
**Last Updated:** 2026-02-07
**Document Version:** 1.0
