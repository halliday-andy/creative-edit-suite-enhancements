# Phase 5: Face Labeling UI

**Priority:** MEDIUM | **Duration:** 1 week

## Overview

Build user interface for labeling detected faces, linking them to entity records in the knowledge graph.

## What You'll Build

### Components
- **FaceLabelingModal** - Modal to label unlabeled faces
- **FaceTimeline** - Visual timeline showing when people appear
- **AutoLabelingBanner** - Shows auto-labeling results

### Features
- Grid of face thumbnails with appearance counts
- Entity selection dropdown
- "Create New Entity" flow
- Skip option for faces
- Auto-labeling notifications
- Face timeline visualization

### User Flow
1. Video processes → unlabeled faces detected
2. Modal opens showing face thumbnails
3. User selects entity from dropdown OR creates new
4. System updates face_clusters and face_detections
5. Triggers atom enrichment automatically

## Prerequisites

- Phase 4 (Face Detection) complete
- Phase 2 (Entity Management UI) complete
- Entity creation modal working

## Acceptance Criteria

- [ ] Modal opens for clips with unlabeled faces
- [ ] Users can select existing entities
- [ ] "Create New" opens entity modal
- [ ] Labels save correctly to database
- [ ] Auto-labeling notification shows
- [ ] Face timeline displays correctly

## Next Phase

After completing Phase 5, move to [Phase 6: Atom-Face Integration](../phase-6-atom-integration/)
