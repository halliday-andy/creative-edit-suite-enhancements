# Phase 4 Quick Start Guide

**Get Phase 4 (Face Detection & Clustering) running in 30 minutes**

This guide assumes you've completed Phases 1-3 and are ready to add face detection.

---

## 🚀 Quick Setup (5 minutes)

### 1. Verify Prerequisites

```bash
# Check database schema
psql $DATABASE_URL -c "\d face_detections"
psql $DATABASE_URL -c "\d face_clusters"

# Verify pgvector extension
psql $DATABASE_URL -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

### 2. Download Face Detection Models

```bash
# Create models directory
mkdir -p supabase/functions/_shared/models

cd supabase/functions/_shared/models

# Download face-api.js models (these are small ~5MB total)
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/ssd_mobilenetv1_model-weights_manifest.json
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/ssd_mobilenetv1_model-shard1
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/face_landmark_68_model-weights_manifest.json
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/face_landmark_68_model-shard1
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/face_recognition_model-weights_manifest.json
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/face_recognition_model-shard1
wget https://github.com/justadudewhohacks/face-api.js-models/raw/master/face_recognition_model-shard2
```

### 3. Install Dependencies

```bash
cd supabase/functions
npm install face-api.js
```

---

## 📝 Implementation Steps

### Step 1: Create face-detect Edge Function (10 minutes)

```bash
# Create function directory
supabase functions new face-detect
```

**File: `supabase/functions/face-detect/index.ts`**

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as faceapi from 'npm:face-api.js';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

// Model caching
let modelsLoaded = false;

async function loadModels() {
  if (modelsLoaded) return;

  await faceapi.nets.ssdMobilenetv1.loadFromDisk('./models');
  await faceapi.nets.faceLandmark68Net.loadFromDisk('./models');

  modelsLoaded = true;
  console.log('Models loaded');
}

serve(async (req) => {
  try {
    const { clipId, videoUrl } = await req.json();

    await loadModels();

    // TODO: Download video, extract frames, detect faces
    // TODO: Insert face_detections records

    return new Response(
      JSON.stringify({ success: true, message: 'Face detection complete' }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

**Deploy:**
```bash
supabase functions deploy face-detect
```

### Step 2: Create face-embed Edge Function (5 minutes)

```bash
supabase functions new face-embed
```

**File: `supabase/functions/face-embed/index.ts`**

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as faceapi from 'npm:face-api.js';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

let modelsLoaded = false;

async function loadModels() {
  if (modelsLoaded) return;
  await faceapi.nets.faceRecognitionNet.loadFromDisk('./models');
  modelsLoaded = true;
}

serve(async (req) => {
  try {
    const { clipId } = await req.json();

    await loadModels();

    // Fetch face_detections without embeddings
    const { data: detections } = await supabase
      .from('face_detections')
      .select('*')
      .eq('clip_id', clipId)
      .is('face_embedding', null);

    // TODO: Generate embeddings for each detection
    // TODO: Update face_detections with embeddings

    return new Response(
      JSON.stringify({ success: true, count: detections?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

**Deploy:**
```bash
supabase functions deploy face-embed
```

### Step 3: Create face-cluster Edge Function (5 minutes)

```bash
supabase functions new face-cluster
```

**File: `supabase/functions/face-cluster/index.ts`**

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magA * magB);
}

serve(async (req) => {
  try {
    const { clipId } = await req.json();

    // Fetch faces with embeddings
    const { data: faces } = await supabase
      .from('face_detections')
      .select('*')
      .eq('clip_id', clipId)
      .not('face_embedding', 'is', null);

    // TODO: Run DBSCAN clustering
    // TODO: Match against existing clusters
    // TODO: Create new clusters or link to existing
    // TODO: Update face_detections with cluster_id

    return new Response(
      JSON.stringify({ success: true, faces: faces?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

**Deploy:**
```bash
supabase functions deploy face-cluster
```

### Step 4: Create SQL Helper Function (2 minutes)

```sql
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION find_similar_cluster(
  query_embedding vector(512),
  similarity_threshold float DEFAULT 0.6
)
RETURNS TABLE (
  id uuid,
  similarity float
) AS $$
  SELECT
    fc.id,
    1 - (fd.face_embedding <=> query_embedding) as similarity
  FROM face_clusters fc
  JOIN face_detections fd
    ON fc.representative_detection_id = fd.id
  WHERE 1 - (fd.face_embedding <=> query_embedding) > similarity_threshold
  ORDER BY similarity DESC
  LIMIT 1;
$$ LANGUAGE sql;
```

### Step 5: Update Pipeline Integration (3 minutes)

Add to `supabase/functions/process-video/index.ts`:

```typescript
// After analyze-atoms completes...

try {
  console.log('Starting face processing...');

  // Face detection
  const detectResponse = await supabase.functions.invoke('face-detect', {
    body: { clipId, videoUrl }
  });

  // Embedding generation
  const embedResponse = await supabase.functions.invoke('face-embed', {
    body: { clipId }
  });

  // Clustering
  const clusterResponse = await supabase.functions.invoke('face-cluster', {
    body: { clipId }
  });

  console.log('Face processing complete');
} catch (error) {
  console.error('Face processing failed:', error);
  // Don't block pipeline - continue to mark clip as ready
}

// Mark clip as ready
await supabase
  .from('clips')
  .update({ status: 'ready' })
  .eq('id', clipId);
```

---

## 🧪 Test It Out

### 1. Upload a Test Video

```bash
# Using Lovable UI or via API
curl -X POST https://your-project.supabase.co/functions/v1/process-video \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -d '{"videoUrl": "your-test-video.mp4"}'
```

### 2. Check Results

```sql
-- View detected faces
SELECT
  clip_id,
  timestamp_seconds,
  bbox_x,
  bbox_y,
  confidence,
  face_cluster_id
FROM face_detections
WHERE clip_id = 'your-clip-id'
ORDER BY timestamp_seconds;

-- View clusters
SELECT
  fc.id,
  fc.cluster_key,
  fc.status,
  COUNT(fd.id) as total_detections
FROM face_clusters fc
JOIN face_detections fd ON fd.face_cluster_id = fc.id
GROUP BY fc.id, fc.cluster_key, fc.status;
```

---

## 🔍 Troubleshooting

### Models Not Loading
```bash
# Check models exist
ls -la supabase/functions/_shared/models/

# Verify permissions
chmod -R 755 supabase/functions/_shared/models/
```

### No Faces Detected
- Check video has visible faces
- Verify frame extraction working (check logs)
- Lower confidence threshold temporarily for testing

### Clustering Issues
- Check embeddings are populated: `SELECT COUNT(*) FROM face_detections WHERE face_embedding IS NOT NULL;`
- Verify DBSCAN parameters (eps=0.35 might be too strict)
- Test with simpler clustering first (all faces = 1 cluster)

### Performance Issues
- Reduce frame rate to 0.5 FPS
- Process only first 30 seconds of video during testing
- Add quality filters (skip confidence < 0.8)

---

## 📚 Next Steps

Once basic functionality works:

1. **Complete Implementation**: Fill in TODOs in each Edge Function
2. **Add Error Handling**: Proper try-catch and error responses
3. **Optimize Performance**: Parallel processing, batching
4. **Run Full Test Suite**: Use IMPLEMENTATION-CHECKLIST-PHASE-4.md
5. **Tune Parameters**: Adjust eps, minSamples, similarity threshold

---

## 📖 Full Documentation

For complete implementation details:
- **LOVABLE-PHASE-4-UPDATED.md** - Complete implementation prompt
- **Phase-4-Technical-Specification.docx** - Technical architecture
- **IMPLEMENTATION-CHECKLIST-PHASE-4.md** - Step-by-step checklist
- **facial-recognition-entity-labeling-spec.md** - Original design spec

---

## 💡 Pro Tips

1. **Start Simple**: Test face-detect alone first before adding embed and cluster
2. **Use Test Videos**: 30-second single-person videos for initial testing
3. **Check Logs**: `supabase functions logs face-detect` for debugging
4. **Iterate Fast**: Deploy often, test frequently
5. **Document Blockers**: Note issues as you encounter them

---

**Time Investment:**
- Setup: 5 minutes
- Function stubs: 20 minutes
- First test: 5 minutes
- **Total: 30 minutes to first test**

Then iterate to full implementation using the complete documentation!

---

**Last Updated:** February 12, 2026
