# Entity System UI Components Specification

## Overview

This document specifies the user interface components needed to integrate entity management and knowledge graph visualization into Creative Edit Suite (Lovable). The UI will enable users to create, view, and manage entities while exploring entity relationships across clips.

## Component Architecture

```
/src
  /pages
    /Entities.tsx                    # Main entity management page (NEW)
  /components
    /entities
      /EntityList.tsx                # Entity list with filtering (NEW)
      /EntityCard.tsx                # Individual entity card (NEW)
      /CreateEntityModal.tsx         # Modal for creating entities (NEW)
      /EntityDetailView.tsx          # Detailed entity view with clips (NEW)
      /EntityChip.tsx                # Small entity badge/chip (NEW)
      /EntityFilter.tsx              # Search filter component (NEW)
    /clips
      /ClipEntityTags.tsx            # Entity tags on clip cards (MODIFY)
      /ClipDetailPanel.tsx           # Add entity section (MODIFY)
```

## 1. Entities Page (`/pages/Entities.tsx`)

### Purpose
Main hub for entity management - view all entities, create new entities, search/filter, and access entity details.

### Layout

```
┌─────────────────────────────────────────────────┐
│ Header: "Knowledge Graph" / "Entities"         │
│ [Create Entity Button]  [Search: _________]    │
│ Filters: [All] [People] [Locations] [Objects]  │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │ Entity  │  │ Entity  │  │ Entity  │  ...  │
│  │  Card   │  │  Card   │  │  Card   │       │
│  └─────────┘  └─────────┘  └─────────┘       │
│                                                 │
│  (Grid layout, 3-4 columns, responsive)        │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Component Structure

```tsx
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import EntityList from '@/components/entities/EntityList';
import CreateEntityModal from '@/components/entities/CreateEntityModal';
import { Button } from '@/components/ui/button';

interface Entity {
  id: string;
  name: string;
  type: 'PERSON' | 'LOCATION' | 'OBJECT' | 'CONCEPT';
  description?: string;
  aliases: string[];
  created_at: string;
  _count?: { clips: number }; // From clip_entities join
}

export default function EntitiesPage() {
  const [entities, setEntities] = useState<Entity[]>([]);
  const [loading, setLoading] = useState(true);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [typeFilter, setTypeFilter] = useState<string>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    fetchEntities();
  }, []);

  async function fetchEntities() {
    setLoading(true);
    const { data, error } = await supabase
      .from('entities')
      .select(`
        *,
        clip_entities (count)
      `)
      .order('name');

    if (!error && data) {
      setEntities(data);
    }
    setLoading(false);
  }

  const filteredEntities = entities.filter(e => {
    const matchesType = typeFilter === 'ALL' || e.type === typeFilter;
    const matchesSearch = e.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         e.aliases.some(a => a.toLowerCase().includes(searchQuery.toLowerCase()));
    return matchesType && matchesSearch;
  });

  return (
    <div className="container mx-auto py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Knowledge Graph</h1>
        <Button onClick={() => setIsCreateModalOpen(true)}>
          Create Entity
        </Button>
      </div>

      <EntityList
        entities={filteredEntities}
        loading={loading}
        onEntityClick={(id) => navigate(`/entities/${id}`)}
      />

      <CreateEntityModal
        open={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onEntityCreated={fetchEntities}
      />
    </div>
  );
}
```

### Features
- **Grid layout** of entity cards (3-4 columns on desktop, responsive)
- **Type filters** (All, People, Locations, Objects, Concepts) as pills/tabs
- **Search bar** with fuzzy matching on name and aliases
- **Create Entity button** opens modal
- **Empty state** when no entities exist with helpful onboarding
- **Loading skeleton** while fetching

## 2. EntityCard Component

### Purpose
Display individual entity in grid with key information and quick actions.

### Design

```
┌────────────────────────────┐
│ [PERSON] 👤                │  <- Type badge + icon
│                            │
│ Kara Smith                 │  <- Name (bold)
│ Host of travel show...     │  <- Description (truncated)
│                            │
│ Aliases: Kara, K. Smith    │  <- Aliases (small text)
│                            │
│ 📊 12 clips                │  <- Clip count
│                            │
│ [View Details]             │  <- Action button
└────────────────────────────┘
```

### Component Structure

```tsx
import { Card, CardHeader, CardContent, CardFooter } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { User, MapPin, Package, Lightbulb } from 'lucide-react';

interface EntityCardProps {
  entity: Entity;
  onClick: (id: string) => void;
}

const ENTITY_ICONS = {
  PERSON: User,
  LOCATION: MapPin,
  OBJECT: Package,
  CONCEPT: Lightbulb
};

const ENTITY_COLORS = {
  PERSON: 'bg-blue-100 text-blue-800',
  LOCATION: 'bg-green-100 text-green-800',
  OBJECT: 'bg-purple-100 text-purple-800',
  CONCEPT: 'bg-orange-100 text-orange-800'
};

export default function EntityCard({ entity, onClick }: EntityCardProps) {
  const Icon = ENTITY_ICONS[entity.type];

  return (
    <Card className="hover:shadow-lg transition-shadow cursor-pointer"
          onClick={() => onClick(entity.id)}>
      <CardHeader className="pb-3">
        <div className="flex items-center gap-2">
          <Badge className={ENTITY_COLORS[entity.type]}>
            <Icon className="w-3 h-3 mr-1" />
            {entity.type}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="space-y-2">
        <h3 className="font-bold text-lg">{entity.name}</h3>

        {entity.description && (
          <p className="text-sm text-gray-600 line-clamp-2">
            {entity.description}
          </p>
        )}

        {entity.aliases.length > 0 && (
          <p className="text-xs text-gray-500">
            Aliases: {entity.aliases.join(', ')}
          </p>
        )}
      </CardContent>

      <CardFooter className="pt-0 flex justify-between items-center">
        <span className="text-sm text-gray-500">
          📊 {entity._count?.clips || 0} clips
        </span>
        <Button variant="ghost" size="sm">
          View Details
        </Button>
      </CardFooter>
    </Card>
  );
}
```

## 3. CreateEntityModal Component

### Purpose
Modal form for creating new entities with validation and autocomplete suggestions.

### Design

```
┌─────────────────────────────────────────┐
│  Create New Entity               [X]    │
├─────────────────────────────────────────┤
│                                         │
│  Name *                                 │
│  [________________________]             │
│                                         │
│  Type *                                 │
│  ○ Person  ○ Location  ○ Object  ○ Concept │
│                                         │
│  Description                            │
│  [________________________]             │
│  [________________________]             │
│                                         │
│  Aliases (comma-separated)              │
│  [________________________]             │
│  e.g., "Bob, Robert, Rob"               │
│                                         │
│  [Cancel]          [Create Entity]      │
└─────────────────────────────────────────┘
```

### Component Structure

```tsx
import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Label } from '@/components/ui/label';
import { supabase } from '@/lib/supabase';
import { toast } from 'sonner';

interface CreateEntityModalProps {
  open: boolean;
  onClose: () => void;
  onEntityCreated: () => void;
}

export default function CreateEntityModal({ open, onClose, onEntityCreated }: CreateEntityModalProps) {
  const [name, setName] = useState('');
  const [type, setType] = useState<'PERSON' | 'LOCATION' | 'OBJECT' | 'CONCEPT'>('PERSON');
  const [description, setDescription] = useState('');
  const [aliases, setAliases] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!name.trim()) {
      toast.error('Name is required');
      return;
    }

    setLoading(true);

    const aliasesArray = aliases
      .split(',')
      .map(a => a.trim())
      .filter(a => a.length > 0);

    const { error } = await supabase
      .from('entities')
      .insert({
        name: name.trim(),
        type,
        description: description.trim() || null,
        aliases: aliasesArray
      });

    setLoading(false);

    if (error) {
      if (error.code === '23505') { // Unique constraint violation
        toast.error(`Entity "${name}" already exists as ${type}`);
      } else {
        toast.error('Failed to create entity');
        console.error(error);
      }
      return;
    }

    toast.success(`Entity "${name}" created!`);
    onEntityCreated();
    onClose();

    // Reset form
    setName('');
    setType('PERSON');
    setDescription('');
    setAliases('');
  }

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Create New Entity</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="name">Name *</Label>
            <Input
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Kara Smith"
              required
            />
          </div>

          <div>
            <Label>Type *</Label>
            <RadioGroup value={type} onValueChange={(v: any) => setType(v)}>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="PERSON" id="person" />
                <Label htmlFor="person">Person</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="LOCATION" id="location" />
                <Label htmlFor="location">Location</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="OBJECT" id="object" />
                <Label htmlFor="object">Object</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="CONCEPT" id="concept" />
                <Label htmlFor="concept">Concept</Label>
              </div>
            </RadioGroup>
          </div>

          <div>
            <Label htmlFor="description">Description</Label>
            <Textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief description of this entity"
              rows={3}
            />
          </div>

          <div>
            <Label htmlFor="aliases">Aliases (comma-separated)</Label>
            <Input
              id="aliases"
              value={aliases}
              onChange={(e) => setAliases(e.target.value)}
              placeholder="e.g., Kara, K. Smith, Kara S."
            />
            <p className="text-xs text-gray-500 mt-1">
              Alternative names or spellings
            </p>
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={loading}>
              {loading ? 'Creating...' : 'Create Entity'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
```

### Features
- **Form validation** (required fields, name uniqueness check)
- **Type selection** with radio buttons and icons
- **Aliases input** with comma-separated format and helper text
- **Error handling** with toast notifications
- **Loading states** during submission

## 4. EntityDetailView Component

### Purpose
Full-page view of an entity showing all clips, timeline, related entities, and management options.

### Layout

```
┌───────────────────────────────────────────────────┐
│ ← Back to Entities                                │
│                                                   │
│ [PERSON] 👤 Kara Smith              [Edit] [Del] │
│ Host of travel show, adventurous eater            │
│ Aliases: Kara, K. Smith                           │
│                                                   │
├───────────────────────────────────────────────────┤
│ First Seen: Episode 12 - Seoul Street Food       │
│ Total Appearances: 24 clips                       │
│                                                   │
│ Timeline ▼                                        │
│ [==========================================]      │
│ 2025 ───●─────●───────────●──────●──── 2026      │
│        Ep12   Ep15       Ep18   Ep20              │
│                                                   │
│ Clips with Kara Smith (24) ▼                     │
│                                                   │
│  ┌──────┐  ┌──────┐  ┌──────┐                   │
│  │Clip 1│  │Clip 2│  │Clip 3│  ...              │
│  └──────┘  └──────┘  └──────┘                   │
│                                                   │
│ Related Entities ▼                                │
│  Often appears with: Nate (18 clips)             │
│  Common locations: Seoul (12), Tokyo (8)          │
│                                                   │
└───────────────────────────────────────────────────┘
```

### Component Structure

```tsx
import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ArrowLeft, Edit, Trash } from 'lucide-react';
import EntityChip from '@/components/entities/EntityChip';

export default function EntityDetailView() {
  const { entityId } = useParams<{ entityId: string }>();
  const navigate = useNavigate();
  const [entity, setEntity] = useState<Entity | null>(null);
  const [clips, setClips] = useState<any[]>([]);
  const [relatedEntities, setRelatedEntities] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchEntityDetails();
  }, [entityId]);

  async function fetchEntityDetails() {
    setLoading(true);

    // Fetch entity
    const { data: entityData } = await supabase
      .from('entities')
      .select('*')
      .eq('id', entityId)
      .single();

    if (entityData) {
      setEntity(entityData);
    }

    // Fetch clips with this entity
    const { data: clipData } = await supabase
      .from('clip_entities')
      .select(`
        clip_id,
        role,
        mention_count,
        first_appearance_seconds,
        clips (id, name, thumbnail_url, duration, created_at)
      `)
      .eq('entity_id', entityId)
      .order('clips(created_at)', { ascending: false });

    if (clipData) {
      setClips(clipData.map(ce => ({
        ...ce.clips,
        role: ce.role,
        mentions: ce.mention_count
      })));
    }

    // Fetch related entities (entities that appear in same clips)
    // TODO: Implement related entity query

    setLoading(false);
  }

  async function handleDelete() {
    if (!confirm(`Delete entity "${entity?.name}"? This cannot be undone.`)) {
      return;
    }

    const { error } = await supabase
      .from('entities')
      .delete()
      .eq('id', entityId);

    if (!error) {
      toast.success('Entity deleted');
      navigate('/entities');
    } else {
      toast.error('Failed to delete entity');
    }
  }

  if (loading) return <div>Loading...</div>;
  if (!entity) return <div>Entity not found</div>;

  return (
    <div className="container mx-auto py-8">
      <Button variant="ghost" onClick={() => navigate('/entities')}>
        <ArrowLeft className="w-4 h-4 mr-2" />
        Back to Entities
      </Button>

      <div className="mt-6 flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <EntityChip entity={entity} size="lg" />
          </div>
          <h1 className="text-3xl font-bold">{entity.name}</h1>
          {entity.description && (
            <p className="text-gray-600 mt-2">{entity.description}</p>
          )}
          {entity.aliases.length > 0 && (
            <p className="text-sm text-gray-500 mt-1">
              Aliases: {entity.aliases.join(', ')}
            </p>
          )}
        </div>

        <div className="flex gap-2">
          <Button variant="outline" size="sm">
            <Edit className="w-4 h-4 mr-1" />
            Edit
          </Button>
          <Button variant="destructive" size="sm" onClick={handleDelete}>
            <Trash className="w-4 h-4 mr-1" />
            Delete
          </Button>
        </div>
      </div>

      <div className="mt-8 grid grid-cols-2 gap-4">
        <div className="p-4 bg-gray-50 rounded">
          <div className="text-sm text-gray-500">Total Appearances</div>
          <div className="text-2xl font-bold">{clips.length} clips</div>
        </div>
        {/* Add more stats */}
      </div>

      <div className="mt-8">
        <h2 className="text-xl font-bold mb-4">Clips with {entity.name} ({clips.length})</h2>
        <div className="grid grid-cols-3 gap-4">
          {clips.map(clip => (
            <ClipCard key={clip.id} clip={clip} />
          ))}
        </div>
      </div>
    </div>
  );
}
```

## 5. EntityChip Component

### Purpose
Small badge/chip for displaying entities inline (in clip cards, search results, etc.)

### Design

```
[👤 Kara Smith]  ← Person (blue)
[📍 Seoul]       ← Location (green)
[📦 Octopus]     ← Object (purple)
[💡 Spicy Food]  ← Concept (orange)
```

### Component Structure

```tsx
import { Badge } from '@/components/ui/badge';
import { User, MapPin, Package, Lightbulb } from 'lucide-react';
import { cn } from '@/lib/utils';

interface EntityChipProps {
  entity: Pick<Entity, 'id' | 'name' | 'type'>;
  size?: 'sm' | 'md' | 'lg';
  onClick?: (id: string) => void;
}

const ENTITY_ICONS = {
  PERSON: User,
  LOCATION: MapPin,
  OBJECT: Package,
  CONCEPT: Lightbulb
};

const ENTITY_COLORS = {
  PERSON: 'bg-blue-100 text-blue-800 hover:bg-blue-200',
  LOCATION: 'bg-green-100 text-green-800 hover:bg-green-200',
  OBJECT: 'bg-purple-100 text-purple-800 hover:bg-purple-200',
  CONCEPT: 'bg-orange-100 text-orange-800 hover:bg-orange-200'
};

export default function EntityChip({ entity, size = 'md', onClick }: EntityChipProps) {
  const Icon = ENTITY_ICONS[entity.type];
  const sizeClasses = {
    sm: 'text-xs px-2 py-0.5',
    md: 'text-sm px-2.5 py-1',
    lg: 'text-base px-3 py-1.5'
  };

  return (
    <Badge
      className={cn(
        ENTITY_COLORS[entity.type],
        sizeClasses[size],
        onClick && 'cursor-pointer'
      )}
      onClick={() => onClick?.(entity.id)}
    >
      <Icon className="w-3 h-3 mr-1" />
      {entity.name}
    </Badge>
  );
}
```

## 6. Clip Modifications

### ClipCard Enhancement

**Add entity chips to clip cards:**

```tsx
// In src/components/clips/ClipCard.tsx

<Card>
  <CardHeader>
    <h3>{clip.name}</h3>
    {/* NEW: Entity tags */}
    {clip.entities && clip.entities.length > 0 && (
      <div className="flex flex-wrap gap-1 mt-2">
        {clip.entities.slice(0, 3).map(entity => (
          <EntityChip key={entity.id} entity={entity} size="sm" />
        ))}
        {clip.entities.length > 3 && (
          <Badge variant="outline" size="sm">
            +{clip.entities.length - 3} more
          </Badge>
        )}
      </div>
    )}
  </CardHeader>
  {/* ... rest of card */}
</Card>
```

### ClipDetailPanel Enhancement

**Add entity section to clip detail panel:**

```tsx
// In src/components/clips/ClipDetailPanel.tsx

<div className="space-y-6">
  {/* Existing sections: thumbnail, metadata, atoms */}

  {/* NEW: Entities section */}
  {clipEntities.length > 0 && (
    <div>
      <h3 className="font-semibold mb-2">Entities</h3>
      <div className="space-y-2">
        {clipEntities.map(ce => (
          <div key={ce.entity.id} className="flex items-center justify-between p-2 bg-gray-50 rounded">
            <EntityChip entity={ce.entity} />
            <div className="text-sm text-gray-500">
              {ce.role} • {ce.mention_count} mentions
            </div>
          </div>
        ))}
      </div>
    </div>
  )}
</div>
```

## 7. Search Enhancement

### EntityFilter Component

**Add entity dropdown to search filters:**

```tsx
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

interface EntityFilterProps {
  selectedEntityId: string | null;
  onEntitySelect: (id: string | null) => void;
}

export default function EntityFilter({ selectedEntityId, onEntitySelect }: EntityFilterProps) {
  const [entities, setEntities] = useState<Entity[]>([]);

  useEffect(() => {
    fetchEntities();
  }, []);

  async function fetchEntities() {
    const { data } = await supabase
      .from('entities')
      .select('id, name, type')
      .order('name');

    if (data) setEntities(data);
  }

  return (
    <Select value={selectedEntityId || ''} onValueChange={(v) => onEntitySelect(v || null)}>
      <SelectTrigger className="w-[200px]">
        <SelectValue placeholder="Filter by entity" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="">All entities</SelectItem>
        {entities.map(entity => (
          <SelectItem key={entity.id} value={entity.id}>
            {entity.name} ({entity.type})
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
```

## Implementation Priority

### Phase 1: Core Entity Management
1. **Entities page** with grid layout
2. **EntityCard** component
3. **CreateEntityModal** component
4. **EntityChip** component

### Phase 2: Entity Integration
5. **ClipCard** entity tags
6. **ClipDetailPanel** entity section
7. **EntityDetailView** page

### Phase 3: Search & Discovery
8. **EntityFilter** in search
9. Entity timeline visualization
10. Related entities logic

## Accessibility Considerations

- **Keyboard navigation:** All interactive elements (cards, chips, buttons) must be keyboard-accessible
- **Screen readers:** Proper ARIA labels for entity types, badges, and role indicators
- **Color contrast:** Entity type colors must meet WCAG AA standards (4.5:1 minimum)
- **Focus indicators:** Visible focus rings on all interactive elements

## Responsive Design

- **Desktop (>1024px):** 3-4 column grid for entity cards
- **Tablet (768-1023px):** 2 column grid
- **Mobile (<768px):** 1 column stack, simplified entity chips

## Testing Strategy

### Unit Tests

```tsx
// Test EntityCard rendering
describe('EntityCard', () => {
  it('renders entity with correct type badge', () => {
    const entity = { name: 'Kara', type: 'PERSON', ... };
    render(<EntityCard entity={entity} />);
    expect(screen.getByText('PERSON')).toBeInTheDocument();
  });
});

// Test CreateEntityModal validation
describe('CreateEntityModal', () => {
  it('shows error when name is empty', async () => {
    render(<CreateEntityModal open={true} />);
    fireEvent.click(screen.getByText('Create Entity'));
    expect(await screen.findByText('Name is required')).toBeInTheDocument();
  });
});
```

### Integration Tests

```tsx
// Test entity creation flow
it('creates entity and appears in list', async () => {
  render(<App />);

  // Navigate to entities page
  fireEvent.click(screen.getByText('Entities'));

  // Open modal
  fireEvent.click(screen.getByText('Create Entity'));

  // Fill form
  fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Test Person' } });
  fireEvent.click(screen.getByLabelText('Person'));

  // Submit
  fireEvent.click(screen.getByText('Create Entity'));

  // Verify in list
  expect(await screen.findByText('Test Person')).toBeInTheDocument();
});
```

## Success Metrics

- **Entity creation:** Users can create 5+ entities in under 2 minutes
- **Entity discovery:** Users find relevant entities via search in <10 seconds
- **Entity detail views:** Users can navigate from entity to clips and back seamlessly
- **Visual clarity:** Entity type badges are distinguishable at a glance
