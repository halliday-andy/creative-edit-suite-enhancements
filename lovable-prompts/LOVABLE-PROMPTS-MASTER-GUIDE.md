# Lovable Implementation Prompts - Master Guide

**Project:** Creative Edit Suite - Entity & Facial Recognition System
**Total Phases:** 7
**Total Timeline:** 8-10 weeks
**Created:** 2026-02-07

---

## 📦 Package Contents

This package contains 7 sequential implementation prompts designed for Lovable AI to implement the entity and facial recognition system.

### Phase Prompts

| Phase | File | Duration | Priority | Status |
|-------|------|----------|----------|--------|
| **Phase 1** | `LOVABLE-PHASE-1-DATABASE-PROMPT.md` | 1-2 weeks | HIGH | 🔴 Not Started |
| **Phase 2** | `LOVABLE-PHASE-2-ENTITY-UI-PROMPT.md` | 1 week | HIGH | 🔴 Not Started |
| **Phase 3** | `LOVABLE-PHASE-3-ATOMIZATION-PROMPT.md` | 1 week | HIGH | 🔴 Not Started |
| **Phase 4** | `LOVABLE-PHASE-4-FACE-DETECTION-PROMPT.md` | 2 weeks | MEDIUM | 🔴 Not Started |
| **Phase 5** | `LOVABLE-PHASE-5-FACE-LABELING-PROMPT.md` | 1 week | MEDIUM | 🔴 Not Started |
| **Phase 6** | `LOVABLE-PHASE-6-ATOM-INTEGRATION-PROMPT.md` | 1 week | MEDIUM | 🔴 Not Started |
| **Phase 7** | `LOVABLE-PHASE-7-SEARCH-PROMPT.md` | 1 week | LOW | 🔴 Not Started |

---

## 🚀 How to Use These Prompts

### Step 1: Start with Phase 1

1. Open Lovable AI interface
2. Copy the entire contents of `LOVABLE-PHASE-1-DATABASE-PROMPT.md`
3. Paste into Lovable chat
4. Attach the `entity-system-migration.sql` file from the repository
5. Let Lovable implement the database foundation

### Step 2: Verify Phase 1 Completion

Before moving to Phase 2:
- [ ] All 4 tables created in Supabase
- [ ] pgvector extension enabled
- [ ] Can insert test entities successfully
- [ ] All acceptance criteria met

### Step 3: Continue Sequentially

Repeat for each phase:
1. Complete current phase
2. Verify acceptance criteria
3. Test functionality
4. Move to next phase

**Important:** Each phase builds on previous phases. Do not skip ahead.

---

## 📋 Phase Dependencies

```
Phase 1 (Database)
    ↓
Phase 2 (Entity UI) ←───┐
    ↓                   │
Phase 3 (Atomization)   │
    ↓                   │
Phase 4 (Face Detection)│
    ↓                   │
Phase 5 (Face Labeling)─┘
    ↓
Phase 6 (Atom Integration)
    ↓
Phase 7 (Enhanced Search)
```

**Minimum Viable Product (MVP):** Phases 1-3
**Full System:** All 7 phases

---

## 🎯 What Gets Built

### Phase 1: Database Foundation (1-2 weeks)
**Output:**
- 4 new tables in Supabase
- pgvector extension enabled
- No UI changes

**Key Deliverable:** Database schema ready for entity storage

### Phase 2: Entity Management UI (1 week)
**Output:**
- `/entities` page
- Entity CRUD operations
- Entity list/detail views

**Key Deliverable:** Users can manually manage entities

### Phase 3: Entity-Aware Atomization (1 week)
**Output:**
- Modified atomization Edge Function
- Automatic entity extraction from transcripts
- Entity linking to clips

**Key Deliverable:** Entities auto-detected during video processing

**🎉 MVP Complete after Phase 3**

### Phase 4: Face Detection & Clustering (2 weeks)
**Output:**
- Face detection Edge Function
- Face embedding generation
- Face clustering algorithm

**Key Deliverable:** System identifies unique individuals in videos

### Phase 5: Face Labeling UI (1 week)
**Output:**
- Face labeling interface
- Entity picker
- Cluster management

**Key Deliverable:** Users can label detected faces with names

### Phase 6: Atom-Face Integration (1 week)
**Output:**
- Atom enrichment algorithm
- Visual entity display in editor
- Auto-enrichment triggers

**Key Deliverable:** Editor shows who is on screen vs mentioned

### Phase 7: Enhanced Search (1 week)
**Output:**
- Entity-based search
- Multi-entity filtering
- Semantic search enhancement

**Key Deliverable:** Search by person name or entity

---

## ✅ Testing Strategy

### After Each Phase

1. **Unit Testing:**
   - Test individual functions
   - Verify database operations
   - Check API responses

2. **Integration Testing:**
   - Test phase with previous phases
   - Verify data flows correctly
   - Check UI integrations

3. **User Testing:**
   - Test with real workflows
   - Verify usability
   - Gather feedback

### Comprehensive Testing (After Phase 7)

**Test Scenario 1: Interview Video**
1. Upload interview with 2 people
2. Process video (atomization + face detection)
3. Label faces with names
4. Search by person name
5. Verify search results accurate

**Test Scenario 2: Multi-Person Meeting**
1. Upload meeting with 5 people
2. Process video
3. Label all 5 faces
4. View atoms in editor
5. Verify visible entities display correctly

**Test Scenario 3: Entity Management**
1. Create person entity "John Doe"
2. Create location entity "San Francisco"
3. Upload video mentioning both
4. Verify entities auto-linked
5. Search by either entity

---

## 🚫 Common Issues & Solutions

### Issue: Lovable Gets Stuck

**Symptoms:**
- Lovable asks clarifying questions repeatedly
- Implementation stops midway

**Solutions:**
- Be specific about file paths
- Confirm technology choices (e.g., "Use face-api.js")
- Break large tasks into smaller steps
- Reference the detailed specs in repository

### Issue: Database Migration Fails

**Symptoms:**
- SQL errors during Phase 1
- Tables not created

**Solutions:**
- Ensure pgvector extension enabled first
- Run migrations in Supabase SQL Editor manually
- Check for syntax errors
- Verify foreign key references exist

### Issue: Face Detection Doesn't Work

**Symptoms:**
- No faces detected in videos
- Edge Function times out

**Solutions:**
- Verify video format supported
- Check frame extraction works
- Tune detection threshold
- Consider using simpler model (face-api.js vs InsightFace)

### Issue: Performance Problems

**Symptoms:**
- Slow search queries
- Timeouts during processing

**Solutions:**
- Verify indexes created correctly
- Check HNSW parameters tuned
- Monitor database query performance
- Consider caching strategies

---

## 📊 Progress Tracking

Use this checklist to track overall progress:

### Phase 1: Database Foundation
- [ ] pgvector extension enabled
- [ ] 4 tables created
- [ ] Test entities inserted
- [ ] Phase 1 complete

### Phase 2: Entity Management UI
- [ ] `/entities` page accessible
- [ ] Can create entities
- [ ] Can edit entities
- [ ] Can delete entities
- [ ] Phase 2 complete

### Phase 3: Entity-Aware Atomization
- [ ] Entity context passed to Gemini
- [ ] Entities extracted from transcripts
- [ ] clip_entities links created
- [ ] Phase 3 complete

**🎯 MVP Checkpoint**

### Phase 4: Face Detection & Clustering
- [ ] Face detection works
- [ ] Face embeddings generated
- [ ] Clustering algorithm works
- [ ] Phase 4 complete

### Phase 5: Face Labeling UI
- [ ] Face labeling page accessible
- [ ] Can view unlabeled clusters
- [ ] Can assign entities to clusters
- [ ] Phase 5 complete

### Phase 6: Atom-Face Integration
- [ ] Atom enrichment algorithm works
- [ ] Visible entities display in editor
- [ ] Auto-enrichment triggers
- [ ] Phase 6 complete

### Phase 7: Enhanced Search
- [ ] Entity search works
- [ ] Multi-entity filtering works
- [ ] Performance acceptable
- [ ] Phase 7 complete

**🎉 Full System Complete!**

---

## 📚 Reference Materials

### For Each Phase

Include these documents when working with Lovable:

**Phase 1:**
- `entity-system-migration.sql`
- `LOVABLE-PHASE-1-DATABASE-PROMPT.md`

**Phase 2:**
- `entity-ui-components-spec.md`
- `LOVABLE-PHASE-2-ENTITY-UI-PROMPT.md`

**Phase 3:**
- `entity-aware-atomization-spec.md`
- `LOVABLE-PHASE-3-ATOMIZATION-PROMPT.md`

**Phase 4:**
- `facial-recognition-entity-labeling-spec.md`
- `LOVABLE-PHASE-4-FACE-DETECTION-PROMPT.md`

**Phase 5:**
- `entity-ui-components-spec.md` (face labeling section)
- `LOVABLE-PHASE-5-FACE-LABELING-PROMPT.md`

**Phase 6:**
- `face-labeling-atom-integration-spec.md`
- `LOVABLE-PHASE-6-ATOM-INTEGRATION-PROMPT.md`

**Phase 7:**
- `LOVABLE-IMPLEMENTATION-PROMPT.md` (search section)
- `LOVABLE-PHASE-7-SEARCH-PROMPT.md`

### Repository Location

All reference documents are in:
`creative-edit-suite-enhancements` repository

---

## 💡 Tips for Success

### 1. One Phase at a Time
Don't try to implement multiple phases simultaneously. Complete and test each phase fully before moving on.

### 2. Verify Before Proceeding
Use the acceptance criteria in each prompt to verify completion before starting next phase.

### 3. Keep Reference Docs Handy
Have the detailed specs open while working with Lovable for quick reference.

### 4. Test Incrementally
Test each feature as it's built, don't wait until end of phase.

### 5. Document Issues
Keep notes of any problems encountered and solutions for future reference.

### 6. Backup Database
Before major migrations, backup your Supabase database.

### 7. Use Version Control
Commit code after each successful phase completion.

---

## 🔄 Rollback Strategy

If you need to undo a phase:

### Phase 1 Rollback
```sql
DROP TABLE IF EXISTS clip_entities CASCADE;
DROP TABLE IF EXISTS face_clusters CASCADE;
DROP TABLE IF EXISTS face_detections CASCADE;
DROP TABLE IF EXISTS entities CASCADE;
```

### Phase 2-7 Rollback
- Remove UI components
- Delete Edge Functions
- Revert code changes via git

**Note:** Always test rollback procedure in staging environment first.

---

## 📞 Support

### If You Get Stuck

1. **Review the detailed specs** in the repository
2. **Check Supabase logs** for database errors
3. **Test components individually** before integration
4. **Consult the acceptance criteria** in each prompt
5. **Break down complex tasks** into smaller steps

### Common Lovable Questions

**Q: "Which file should I create?"**
A: Refer to the file paths specified in the prompt (e.g., `/src/services/entityService.ts`)

**Q: "Should I use X or Y technology?"**
A: Use the technology specified in the prompt (e.g., "Use face-api.js")

**Q: "How should I structure this?"**
A: Follow the code examples provided in the prompt

---

## 🎯 Success Metrics

### MVP Success (After Phase 3)
- [ ] Can create/edit entities manually
- [ ] Video processing auto-detects entities
- [ ] Entities linked to clips correctly
- [ ] Can search clips by entity

### Full System Success (After Phase 7)
- [ ] Face detection accuracy > 85%
- [ ] Face clustering groups same person correctly
- [ ] Face labeling UI intuitive
- [ ] Search by face works accurately
- [ ] Editor shows visual entities
- [ ] Performance acceptable (< 5 min for 10-min video)

---

## ⏭️ Next Steps

1. ✅ Review this master guide completely
2. ✅ Ensure you have access to creative-edit-suite-enhancements repository
3. ✅ Open Lovable AI interface
4. ✅ Start with Phase 1 prompt
5. ✅ Follow sequential implementation

**Ready to begin?** Start with Phase 1! 🚀

---

**Document Version:** 1.0
**Last Updated:** 2026-02-07
**Total Prompts:** 7
**Estimated Timeline:** 8-10 weeks
**Status:** Ready for Implementation
