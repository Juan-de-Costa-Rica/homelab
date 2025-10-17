# Handoff Document: Immich + Nextcloud Integration Configuration

**Date:** 2025-10-17
**Server:** debian-langosta
**Session Summary:** Configured Immich and Nextcloud for bidirectional photo sharing with external library support

> **Note to Future Agents:** Please maintain a professional tone in this setting. Limit emoji use to occasional checkmarks (✓/✅) or minimal functional indicators. Avoid excessive decorative emoji.

> **Git Workflow:** Commit changes to git frequently as you work. When a feature is complete and tested, ask the user for permission before pushing to GitHub. Example: "I've completed the configuration and verified it's working. Would you like me to push these changes to GitHub?"

---

## What Was Done

### Problem Statement
User wanted to integrate Immich photo management with Nextcloud file sync, with the following requirements:
1. Bulk upload existing photos via Nextcloud
2. Daily phone photo auto-upload via Nextcloud Android app
3. Screenshot uploads from laptop via Nextcloud
4. Immich AI features (face recognition, search) on all photos
5. Ability to reorganize photos in Nextcloud without breaking Immich
6. Clean folder structure (no UUID folders visible)
7. All photos synced to laptop via Nextcloud desktop client

### Initial Challenges
- Original config had `homelab_shared_photos` containing all Immich internal data (thumbs, uploads, encoded-video, etc.)
- Nextcloud was mounting this volume and seeing all the technical folders
- UUID-based folder structure from Immich's internal library
- Conflicting volume mounts causing container failures

### Solution Implemented
**Immich as read-only AI layer** on top of Nextcloud photo library:
- Immich has its own internal data volume (`homelab_services_immich_data`)
- Nextcloud manages the shared photo library (`homelab_shared_photos`)
- Immich uses External Library feature to watch and index Nextcloud photos (read-only)
- User controls all file organization via Nextcloud

---

## Configuration Changes

### File: `~/homelab/services/immich.docker-compose.yaml`

**Changes Made:**
1. **Simplified volume structure:**
   ```yaml
   volumes:
     # IMMICH INTERNAL DATA - All internal files in one volume
     - homelab_services_immich_data:/data

     # NEXTCLOUD PHOTO LIBRARY - External library (read-only)
     - homelab_shared_photos:/mnt/nextcloud-photos:ro

     # System timezone
     - /etc/localtime:/etc/localtime:ro
   ```

2. **Removed all separate subdirectory volumes** (thumbs, upload, encoded-video, profile, backups)
   - These are now subdirectories within `homelab_services_immich_data:/data`

3. **Added read-only mount** of `homelab_shared_photos` to `/mnt/nextcloud-photos`
   - This prevents Immich from modifying user's photos
   - Immich will use this as an External Library path

**Backups Created:**
- `~/homelab/services/immich.docker-compose.yaml.backup-YYYYMMDD-HHMMSS`

### File: `~/homelab/services/nextcloud.docker-compose.yaml`

**Changes Made:**
1. **Updated shared photos mount** (2 locations - nextcloud-app and nextcloud-cron):
   ```yaml
   # OLD:
   - homelab_shared_photos:/var/www/html/data/__media__/photos/library

   # NEW:
   - homelab_shared_photos:/var/www/html/data/__media__/photos
   ```

2. **Removed `/library` subdirectory** from mount path for clean structure

### Nextcloud External Storage Configuration

**Created via OCC commands:**
```bash
# Create external storage mount
docker exec -u www-data nextcloud-app php occ files_external:create \
  '/Media/Photos' 'local' 'null::null' \
  -c datadir='/var/www/html/data/__media__/photos' \
  --user=juan

# Enable sharing
docker exec -u www-data nextcloud-app php occ files_external:option 8 enable_sharing true

# Verify mount
docker exec -u www-data nextcloud-app php occ files_external:verify 8

# Scan files
docker exec -u www-data nextcloud-app php occ files:scan --path=/juan/files/Media/Photos
```

**Result:**
- Mount ID: 8
- Mount Point: `/Media/Photos` (visible in Nextcloud UI)
- Backend Path: `/var/www/html/data/__media__/photos`
- Type: Personal (user-specific)
- Sharing: Enabled
- Status: Verified OK

### Volume Changes

**Cleaned `homelab_shared_photos` volume:**
- Stopped services
- Removed old volume containing Immich test data
- Created fresh empty volume
- Result: Clean slate for user's photo organization

**Created Immich internal structure:**
- Created `.immich` marker files in required directories:
  - `/data/library/.immich`
  - `/data/upload/.immich`
  - `/data/thumbs/.immich`
  - `/data/backups/.immich`
  - `/data/encoded-video/.immich`
  - `/data/profile/.immich`
- These marker files are required by Immich v2.0.0 for mount verification

---

## Technical Details

### Current Volume Structure

```
homelab_services_immich_data (Immich internal)
├── library/          # Immich's managed library (unused in this setup)
├── upload/           # Temporary uploads
├── thumbs/           # Generated thumbnails
├── encoded-video/    # Transcoded videos
├── profile/          # Profile pictures
└── backups/          # Database backups

homelab_shared_photos (User's photos - managed via Nextcloud)
└── (empty - ready for user's organized photos)

homelab_services_immich_db_data (Postgres database)
homelab_services_immich_model_cache (ML models)
```

### Mount Points

**Immich Container (`immich-server`):**
- `/data` → `homelab_services_immich_data` (rw)
- `/mnt/nextcloud-photos` → `homelab_shared_photos` (ro)

**Nextcloud Container (`nextcloud-app` & `nextcloud-cron`):**
- `/var/www/html/data/__media__/photos` → `homelab_shared_photos` (rw)

### Container Status
All containers healthy and running:
```
✅ immich-server (healthy)
✅ immich-machine-learning (healthy)
✅ immich-postgres (healthy)
✅ immich-redis (healthy)
✅ nextcloud-app (healthy)
✅ nextcloud-cron (healthy)
✅ nextcloud-db (healthy)
✅ nextcloud-redis (healthy)
```

---

## Next Steps for User

### Required: Configure Immich External Library

**User must do this in Immich Web UI:**
1. Navigate to: `https://immich.{tailscale-domain}`
2. Go to **Administration** → **External Libraries**
3. Click **Create External Library**
4. Configure:
   - Import Path: `/mnt/nextcloud-photos`
   - ✅ Enable "Scan automatically"
   - ✅ Enable "Watch for file changes"
   - Set scan interval (optional)
5. Click **Save**
6. Click **Scan Now** to index existing photos

### User Workflows

**Bulk Upload (Existing Photos):**
1. Copy organized photos to `~/Nextcloud/__media__/photos/` on laptop
2. Nextcloud desktop client syncs to server
3. Immich External Library scanner indexes them
4. User can organize in any folder structure they want

**Daily Phone Photos:**
1. Nextcloud Android app auto-upload configured
2. Photos go to `/__media__/photos/` on server
3. Sync to laptop via Nextcloud client
4. Immich indexes automatically

**Screenshot/Laptop Uploads:**
1. Drop in `~/Nextcloud/__media__/photos/Screenshots/` (or any folder)
2. Nextcloud syncs → Immich indexes

**Reorganize Photos:**
1. Move/rename files in Nextcloud (any client)
2. Immich re-scans and updates index
3. Original organization preserved

---

## Troubleshooting

### If Immich Fails to Start

**Check for `.immich` marker files:**
```bash
ssh debian-langosta "docker exec immich-server find /data -name .immich"
```

Should show:
```
/data/library/.immich
/data/upload/.immich
/data/thumbs/.immich
/data/backups/.immich
/data/encoded-video/.immich
/data/profile/.immich
```

**If missing, recreate them:**
```bash
ssh debian-langosta "docker run --rm -v homelab_services_immich_data:/data alpine sh -c 'for dir in library upload thumbs backups encoded-video profile; do echo \"1\" > /data/\${dir}/.immich; done'"
```

### If Immich External Library Not Scanning

1. Check mount is readable:
   ```bash
   ssh debian-langosta "docker exec immich-server ls -la /mnt/nextcloud-photos/"
   ```

2. Check Nextcloud photos are present:
   ```bash
   ssh debian-langosta "docker exec nextcloud-app ls -la /var/www/html/data/__media__/photos/"
   ```

3. Verify read-only mount:
   ```bash
   ssh debian-langosta "docker inspect immich-server | grep -A 5 nextcloud-photos"
   ```
   Should show: `"Mode": "ro"`

### If Nextcloud Not Syncing

1. Check Nextcloud client configuration
2. Verify `__media__/photos/` folder exists in Nextcloud
3. Check permissions on laptop sync folder
4. Review Nextcloud desktop client logs

---

## Related Files & Documentation

### Configuration Files Modified
- `~/homelab/services/immich.docker-compose.yaml` ✏️ Modified
- `~/homelab/services/nextcloud.docker-compose.yaml` ✏️ Modified

### Configuration Files Referenced (Not Modified)
- `~/homelab/docker-compose.yaml` (main compose file)
- `~/homelab/services.docker-compose.yaml` (services orchestrator)
- `~/homelab/infrastructure.docker-compose.yaml` (infrastructure services)

### Backups Created
- `~/homelab/services/immich.docker-compose.yaml.backup-YYYYMMDD-HHMMSS`

### External Storage Configuration
User needs to configure in **Nextcloud Web UI**:
- Settings → Administration → External Storage
- Verify `Media/Photos` → `/var/www/html/data/__media__/photos` mapping

---

## Key Learnings

### Immich External Library Feature
- Immich v2.0.0+ supports External Libraries
- Allows Immich to index photos it doesn't manage
- Read-only mode prevents Immich from moving/modifying files
- User retains full control over file organization

### Volume Mounting Strategy
- Avoid overlapping mounts (`/data` + `/data/subdirs`)
- Use single internal volume for Immich's data
- Mount shared volume separately
- Use `:ro` flag for read-only mounts

### Immich `.immich` Marker Files
- Required in v2.0.0 for mount verification
- Must exist in all expected subdirectories
- Content: just "1\n"
- Failure to have these causes container restart loop

### Nextcloud External Storage
- Can mount Docker volumes as external storage
- Preserves file permissions (both use www-data:33)
- Allows organization outside Nextcloud's native structure

---

## Important Notes

### What NOT to Do
- ❌ Don't use Immich mobile app for uploads (use Nextcloud app instead)
- ❌ Don't enable Immich's internal library for this user
- ❌ Don't modify files in `/data/library/[uuid]/` structure
- ❌ Don't remove read-only flag from Immich's mount of shared photos

### Git Repository
- Homelab directory IS a git repository
- Changes have NOT been committed yet
- Need to commit configuration changes before closing session

### Future Considerations
- User wants to upload **daily phone photos** via Nextcloud
- User wants to **bulk upload** organized existing albums
- User wants **full reorganization control** via Nextcloud
- Immich is **supplementary** - provides AI/search only

---

## References

- **Immich Documentation:** https://immich.app/docs
- **Immich External Libraries:** https://immich.app/docs/features/libraries
- **System Integrity Checks:** https://immich.app/docs/administration/system-integrity
- **Nextcloud External Storage:** https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/external_storage_configuration_gui.html

---

## Quick Commands Reference

```bash
# Check all container status
ssh debian-langosta "docker ps | grep -E '(immich|nextcloud)'"

# Restart Immich
ssh debian-langosta "cd ~/homelab && docker compose restart immich-server"

# Restart Nextcloud
ssh debian-langosta "cd ~/homelab && docker compose restart nextcloud-app nextcloud-cron"

# View Immich logs
ssh debian-langosta "docker logs immich-server --tail 50"

# Check shared photos (Immich view)
ssh debian-langosta "docker exec immich-server ls -la /mnt/nextcloud-photos/"

# Check shared photos (Nextcloud view)
ssh debian-langosta "docker exec nextcloud-app ls -la /var/www/html/data/__media__/photos/"

# Verify mounts
ssh debian-langosta "docker inspect immich-server --format '{{json .Mounts}}' | python3 -m json.tool"
```

---

## Session Checklist

**Completed:**
- [x] Analyzed existing Immich/Nextcloud configuration
- [x] Identified volume structure issues
- [x] Redesigned configuration for External Library approach
- [x] Updated `immich.docker-compose.yaml`
- [x] Updated `nextcloud.docker-compose.yaml`
- [x] Cleaned `homelab_shared_photos` volume
- [x] Created Immich internal directory structure
- [x] Created required `.immich` marker files
- [x] Restarted all services
- [x] Verified all containers healthy
- [x] Confirmed clean empty shared volume
- [x] **Configured Nextcloud External Storage via OCC** (Mount ID: 8)
- [x] Verified external storage mount works
- [x] Tested end-to-end file visibility (Nextcloud → Immich)
- [x] Documented complete setup for user
- [x] **Committed changes to git repository**

**Pending (for user or next session):**
- [ ] Configure Immich External Library in Web UI (point to `/mnt/nextcloud-photos`)
- [ ] Test photo upload from Nextcloud web/mobile
- [ ] Verify Immich indexes uploaded photos
- [ ] Set up Nextcloud auto-upload on Android phones
- [ ] Bulk upload existing organized photos
- [ ] **Ask user permission before pushing to GitHub**

---

## Immich Folder Album Creator (Added 2025-10-17)

### Overview
Automatically creates Immich albums based on your Nextcloud folder structure. This solves the problem of maintaining your organized album structure in Immich without manual album creation.

### Configuration Added

Added new service to `~/homelab/services/immich.docker-compose.yaml`:

```yaml
immich-folder-album-creator:
  image: salvoxia/immich-folder-album-creator:latest
  container_name: immich-folder-album-creator
  restart: unless-stopped

  depends_on:
    immich-server:
      condition: service_healthy

  volumes:
    # Mount shared photos at same path as immich-server sees it
    - homelab_shared_photos:/mnt/nextcloud-photos:ro

  environment:
    API_URL: http://immich-server:2283/api
    API_KEY: ${IMMICH_API_KEY}
    ROOT_PATH: /mnt/nextcloud-photos
    ALBUM_LEVELS: -1
    ALBUM_LEVEL_SEPARATOR: " - "
    CRON_EXPRESSION: "0 2 * * *"
    TZ: ${TZ}
    MODE: CREATE
    UNATTENDED: 1
```

### Key Configuration Details

**ROOT_PATH:** MUST match the path as stored in Immich's database (`originalPath` field). In our setup, this is `/mnt/nextcloud-photos` - not `/external_libs/photos` or any other path. The script filters assets by this path prefix.

**ALBUM_LEVELS: -1:** Creates albums for ALL folder levels (unlimited depth). This handles:
- Top-level folders: "2024 Oaxaca", "Random CR", etc.
- Nested folders: "fb bar1 albums/cumple jon", "fb jon albums/Beach Trip 2019"
- Each folder becomes its own album (no parent path prefix in album name)

**ALBUM_LEVEL_SEPARATOR:** When parent paths are included in names, this separator is used (e.g., "Parent - Child"). With `ALBUM_LEVELS: -1`, nested folders get clean names without prefixes.

**CRON_EXPRESSION: "0 2 * * *":** Runs daily at 2am to sync new photos/folders automatically.

**UNATTENDED: 1:** Runs without interactive prompts (required for automated/cron execution).

### How It Works

1. Queries Immich API for all assets in external library
2. Filters assets to those with `originalPath` starting with ROOT_PATH
3. Extracts folder names from paths
4. Creates/updates albums to match folder structure
5. Adds photos to corresponding albums

### Initial Run Results

**Date:** 2025-10-17
**Assets Found:** 9,276 photos
**Albums Created:** 83 albums

Sample albums created:
- 2020 Ecuador Covid
- 2024 Oaxaca
- fb bar1 albums (parent folder with direct photos)
- cumple jon (nested inside fb bar1 albums)
- anexion guana (nested inside fb bar1 albums)
- Random CR
- Greece Serbia May 2022

### Manual Execution

To manually trigger album sync (useful after bulk photo uploads):

```bash
# Run album creator manually
ssh debian-langosta "docker exec immich-folder-album-creator /script/immich_auto_album.sh"

# Check logs
ssh debian-langosta "docker logs immich-folder-album-creator --tail 50"
```

### Workflow Integration

**When you add new photos to Nextcloud:**
1. Upload photos to organized folders in Nextcloud (via web/mobile/desktop client)
2. Nextcloud syncs to server (`homelab_shared_photos` volume)
3. Immich External Library scanner indexes photos (automatic or manual trigger)
4. Album Creator runs at 2am daily to create/update albums
5. Photos appear in Immich organized by folder-based albums

**For immediate album sync:**
```bash
ssh debian-langosta "docker exec immich-folder-album-creator /script/immich_auto_album.sh"
```

### Important Notes

**Album Names:** With `ALBUM_LEVELS: -1`, nested folders get their own albums without parent prefixes. If you have duplicate folder names at different levels (e.g., "2023/Vacation" and "2024/Vacation"), they will conflict and use the same album. Your current structure doesn't have this issue.

**Album Modifications:** Albums created by this script are standard Immich albums. You can:
- Add/remove photos manually in Immich
- Rename albums (changes will be overwritten on next sync)
- Delete albums (will be recreated on next sync if folder still exists)
- Set album covers, descriptions, etc.

**Folder Changes:** If you rename/move folders in Nextcloud:
- Old album will remain in Immich (not auto-deleted)
- New album will be created for new folder name
- You may want to manually clean up old albums

### Troubleshooting

**Albums not being created:**
1. Check ROOT_PATH matches Immich database paths:
   ```bash
   ssh debian-langosta "docker exec immich-postgres psql -U immich -d immich -c \"SELECT \\\"originalPath\\\" FROM asset LIMIT 5;\""
   ```
   Paths should start with `/mnt/nextcloud-photos`

2. Verify mount is accessible:
   ```bash
   ssh debian-langosta "docker exec immich-folder-album-creator ls -la /mnt/nextcloud-photos/"
   ```

3. Check API key is valid:
   ```bash
   ssh debian-langosta "docker exec immich-folder-album-creator env | grep API_KEY"
   ```

**Run with debug output:**
```bash
ssh debian-langosta "docker exec immich-folder-album-creator /script/immich_auto_album.sh -d"
```

### Related Files

**Modified:**
- `~/homelab/services/immich.docker-compose.yaml` (added album creator service)

**Uses:**
- `~/homelab/.env` (contains `IMMICH_API_KEY`)

**References:**
- GitHub: https://github.com/Salvoxia/immich-folder-album-creator
- Docker Hub: https://hub.docker.com/r/salvoxia/immich-folder-album-creator
- Listed on Immich's official Community Projects page

---

**End of Handoff Document**
