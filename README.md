# HLS Adaptive Bitrate Streaming Pipeline

A fully containerized video processing pipeline that converts a source MP4 into an **HLS (HTTP Live Streaming)** adaptive bitrate stream. Built with **FFmpeg**, **Nginx**, and **Docker Compose**.

## 🎬 What It Does

1. **Processor** container transcodes `video/source.mp4` into 3 HLS quality renditions using FFmpeg
2. **Web Server** container (Nginx) serves the HLS files with proper CORS headers and MIME types
3. A video player (VLC, HLS.js, etc.) adaptively switches quality based on network conditions

### Quality Renditions

| Resolution | Bitrate (Video) | Bitrate (Audio) | Segment Size (approx.) |
|-----------|-----------------|-----------------|------------------------|
| 1080p     | 5000 kbps       | 192 kbps        | ~4 MB / segment        |
| 720p      | 2500 kbps       | 128 kbps        | ~2 MB / segment        |
| 480p      |  800 kbps       | 128 kbps        | ~700 KB / segment      |

---

## 📋 Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Docker Compose)
- A source video file (`source.mp4`) — see step below

---

## 🚀 Quick Start

### Step 1: Get Source Video

Download the [Big Buck Bunny](https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_30fps_normal.mp4) test video (or use any MP4) and place it at:

```
video/source.mp4
```

> ⚠️ The `video/source.mp4` file is excluded from Git (see `.gitignore`). You must download/copy it manually.

### Step 2: Build and Run

```bash
docker-compose up --build
```

The processor will transcode the video (takes several minutes depending on source length and hardware). When complete, the web server will be available.

### Step 3: Access the Stream

| Resource            | URL                                               |
|---------------------|---------------------------------------------------|
| **Master Playlist** | http://localhost:8080/media/output/master.m3u8    |
| 1080p Playlist      | http://localhost:8080/media/output/1080/stream.m3u8 |
| 720p Playlist       | http://localhost:8080/media/output/720/stream.m3u8  |
| 480p Playlist       | http://localhost:8080/media/output/480/stream.m3u8  |

---

## 🧪 Testing the Stream

### VLC Player
1. Open VLC → **Media** → **Open Network Stream**
2. Enter: `http://localhost:8080/media/output/master.m3u8`
3. Click **Play**

### Browser (HLS.js)
Open the following URL in any modern browser after starting the stack:
```
http://localhost:8080/media/player.html
```
*(A basic HLS.js player page is included.)*

### cURL Verification
```bash
# Check master playlist
curl -I http://localhost:8080/media/output/master.m3u8

# Verify CORS header
curl -s -I http://localhost:8080/media/output/master.m3u8 | grep -i access-control

# View master playlist content
curl http://localhost:8080/media/output/master.m3u8

# Check a video segment
curl -I http://localhost:8080/media/output/480/seg000.ts
```

---

## 📁 Project Structure

```
task-13/
├── docker-compose.yml      # Orchestrates processor + web_server
├── Dockerfile.nginx        # Nginx web server image
├── nginx.conf              # Nginx config (CORS + MIME types)
├── process.sh              # FFmpeg HLS transcoding script
├── .env.example            # Example environment variables
├── .gitignore              # Excludes media/ and source video
├── README.md               # This file
│
├── video/                  # Source video directory
│   ├── .gitkeep            # Keeps directory in Git
│   └── source.mp4          # ← Place your source video here (not in Git)
│
└── media/                  # Generated output (not in Git)
    └── output/
        ├── master.m3u8     # HLS master playlist
        ├── 1080/
        │   ├── stream.m3u8 # 1080p variant playlist
        │   ├── seg000.ts
        │   └── ...
        ├── 720/
        │   ├── stream.m3u8 # 720p variant playlist
        │   └── ...
        └── 480/
            ├── stream.m3u8 # 480p variant playlist
            └── ...
```

---

## ⚙️ Configuration

Copy `.env.example` to `.env` and adjust values:

```bash
cp .env.example .env
```

| Variable          | Default | Description                               |
|-------------------|---------|-------------------------------------------|
| `SEGMENT_DURATION`| `6`     | HLS segment duration in seconds           |
| `FFMPEG_PRESET`   | `fast`  | FFmpeg encoding speed vs quality tradeoff |
| `BITRATE_1080P`   | `5000k` | 1080p video bitrate                       |
| `BITRATE_720P`    | `2500k` | 720p video bitrate                        |
| `BITRATE_480P`    | `800k`  | 480p video bitrate                        |

---

## 🔄 Re-processing

The processing script is **idempotent** — it skips transcoding if `media/output/master.m3u8` already exists.

To force re-processing:
```bash
# Remove existing output
rm -rf media/output

# Re-run
docker-compose run processor
```

---

## 🛑 Stopping

```bash
docker-compose down
```

---

## 🔍 How It Works

### Adaptive Bitrate Streaming (HLS)
1. FFmpeg reads `source.mp4` and produces **three parallel output streams** in a single pass
2. Each stream is segmented into 6-second `.ts` (MPEG-2 Transport Stream) files
3. A `stream.m3u8` variant playlist is created per rendition listing all its segments  
4. A `master.m3u8` master playlist ties all variants together, with bandwidth + resolution metadata
5. The HLS player downloads the master playlist, measures network speed, and picks the best variant
6. As bandwidth changes, the player seamlessly switches between 480p, 720p, and 1080p segments

### CORS & MIME Types
Nginx is configured to:
- Send `Access-Control-Allow-Origin: *` on all responses (required for browser playback)
- Serve `.m3u8` files with `application/vnd.apple.mpegurl`
- Serve `.ts` files with `video/MP2T`
- Handle `OPTIONS` preflight requests with `204`

---

## 📦 Technologies

| Technology | Role |
|-----------|------|
| **FFmpeg** | Video transcoding, HLS segmentation |
| **Nginx** | Static HTTP server for HLS files |  
| **Docker** | Containerization |
| **Docker Compose** | Multi-container orchestration |
| **HLS** | Adaptive bitrate streaming protocol |

---

## 🌐 Master Playlist URL

```
http://localhost:8080/media/output/master.m3u8
```
