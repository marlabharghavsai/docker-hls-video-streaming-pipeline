#!/bin/bash
# =============================================================================
# HLS Adaptive Bitrate Streaming - Video Processing Script
# Transcodes source.mp4 into 3 quality renditions (1080p, 720p, 480p)
# and generates HLS playlists and segments.
# =============================================================================

set -e  # Exit immediately on any error

# --- Configuration ---
SOURCE="/app/video/source.mp4"
OUTPUT="/app/media/output"
SEGMENT_DURATION=6   # seconds per .ts segment

# --- Idempotency Check ---
if [ -f "${OUTPUT}/master.m3u8" ]; then
    echo "[INFO] master.m3u8 already exists. Skipping transcoding."
    echo "[INFO] Delete ${OUTPUT} to force re-processing."
    exit 0
fi

# --- Validate Source ---
if [ ! -f "${SOURCE}" ]; then
    echo "[ERROR] Source video not found at ${SOURCE}"
    echo "[ERROR] Please place your source.mp4 in the ./video/ directory."
    exit 1
fi

echo "[INFO] Source video found: ${SOURCE}"
echo "[INFO] Output directory:   ${OUTPUT}"

# --- Create Output Directories ---
mkdir -p "${OUTPUT}/1080"
mkdir -p "${OUTPUT}/720"
mkdir -p "${OUTPUT}/480"

echo "[INFO] Starting FFmpeg transcoding (this may take a while)..."

# =============================================================================
# FFmpeg Command
# Produces three HLS renditions in a single pass for efficiency.
#
# Renditions:
#   1080p: 5000k video + 192k audio
#    720p: 2500k video + 128k audio
#    480p:  800k video + 128k audio
#
# Flags:
#   -c:v libx264     - H.264 video codec (broadest compatibility)
#   -c:a aac         - AAC audio codec
#   -hls_time        - Target segment duration in seconds
#   -hls_playlist_type vod - Mark playlist as Video On Demand
#   -hls_segment_filename  - Pattern for segment file names
#   -hls_flags independent_segments - Each segment can be decoded independently
# =============================================================================

ffmpeg -y \
    -i "${SOURCE}" \
    \
    -filter_complex \
    "[0:v]split=3[v1][v2][v3]; \
     [v1]scale=w=1920:h=1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2[vout1080]; \
     [v2]scale=w=1280:h=720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[vout720]; \
     [v3]scale=w=854:h=480:force_original_aspect_ratio=decrease,pad=854:480:(ow-iw)/2:(oh-ih)/2[vout480]" \
    \
    -map "[vout1080]" -map 0:a \
    -c:v:0 libx264 -preset fast -crf 22 \
    -b:v:0 5000k -maxrate:v:0 5350k -bufsize:v:0 7500k \
    -c:a:0 aac -b:a:0 192k -ar 48000 \
    -hls_time ${SEGMENT_DURATION} \
    -hls_playlist_type vod \
    -hls_flags independent_segments \
    -hls_segment_filename "${OUTPUT}/1080/seg%03d.ts" \
    "${OUTPUT}/1080/stream.m3u8" \
    \
    -map "[vout720]" -map 0:a \
    -c:v:1 libx264 -preset fast -crf 23 \
    -b:v:1 2500k -maxrate:v:1 2675k -bufsize:v:1 3750k \
    -c:a:1 aac -b:a:1 128k -ar 48000 \
    -hls_time ${SEGMENT_DURATION} \
    -hls_playlist_type vod \
    -hls_flags independent_segments \
    -hls_segment_filename "${OUTPUT}/720/seg%03d.ts" \
    "${OUTPUT}/720/stream.m3u8" \
    \
    -map "[vout480]" -map 0:a \
    -c:v:2 libx264 -preset fast -crf 24 \
    -b:v:2 800k  -maxrate:v:2 856k  -bufsize:v:2 1200k \
    -c:a:2 aac -b:a:2 128k -ar 48000 \
    -hls_time ${SEGMENT_DURATION} \
    -hls_playlist_type vod \
    -hls_flags independent_segments \
    -hls_segment_filename "${OUTPUT}/480/seg%03d.ts" \
    "${OUTPUT}/480/stream.m3u8"

echo "[INFO] FFmpeg transcoding complete."

# =============================================================================
# Generate Master Playlist
# The master playlist references each variant stream with its bandwidth
# and resolution metadata. The player uses this to select the best quality.
# =============================================================================

cat > "${OUTPUT}/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3

#EXT-X-STREAM-INF:BANDWIDTH=5192000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
1080/stream.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=2628000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
720/stream.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=928000,RESOLUTION=854x480,CODECS="avc1.42e01e,mp4a.40.2"
480/stream.m3u8
EOF

echo "[INFO] Master playlist generated: ${OUTPUT}/master.m3u8"
echo "[INFO] ================================================"
echo "[INFO]  Stream is ready!"
echo "[INFO]  Master playlist: http://localhost:8080/media/output/master.m3u8"
echo "[INFO] ================================================"
