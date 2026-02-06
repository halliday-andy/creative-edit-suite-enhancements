# Phase 2: Entity Management UI

**Priority:** HIGH | **Duration:** 1 week

## Overview

Build the entity management interface so users can create, view, and manage entities through the UI.

## What's Included

- [`entity-ui-components-spec.md`](./entity-ui-components-spec.md) - Complete UI specifications

## What You'll Build

### Pages
- `/entities` - Entity list/grid view
- `/entities/:id` - Entity detail view

### Components
- **EntityList** - Grid of entity cards (3-4 columns, responsive)
- **EntityCard** - Individual entity display with type badge
- **CreateEntityModal** - Form for creating new entities
- **EntityDetailView** - Full entity view with related clips
- **EntityChip** - Small entity badge for use in other components
- **EntityFilter** - Search and filter controls

### Features
- Type filters (All, People, Locations, Objects, Concepts)
- Fuzzy search by name/alias
- Entity CRUD operations
- Type-specific colors and icons

## Prerequisites

- Phase 1 (Database Foundation) complete
- Supabase client configured
- shadcn/ui components installed

## Acceptance Criteria

- [ ] Entity list page loads and displays entities
- [ ] Create entity modal works with validation
- [ ] Entity detail page shows related clips
- [ ] Search and filters function correctly
- [ ] Entity chips render with proper styling

## Next Phase

After completing Phase 2, move to [Phase 3: Entity-Aware Atomization](../phase-3-atomization/)
