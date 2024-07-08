# Audio Splicer
 
## Introduction

This script automates the process of splitting audiobooks and podcasts into smaller segments for playback on an MP3 player, optimized for activities like swimming.

## Features

- **Segmentation**: Splits audio files into user-defined durations.
- **Announcements**: Includes track announcements between segments.
- **Water MP3 Player Mode**: Enhances voice clarity for low-quality playback.

## Usage

```bash
Usage: ./audio_split.sh -i <input_file> [-d <max_splice_duration>] [-o <output_directory>] [-w] [-v]
```

- `-i`: Input audio file path (required)
- `-d`: Maximum splice duration in minutes (optional, default: 10)
- `-o`: Output directory (optional, default: same as input file)
- `-w`: Water MP3 player mode (optional)
- `-v`: Verbose mode (optional)

## Requirements

- **FFmpeg**: Required for audio processing. Install via your package manager or [ffmpeg.org](https://ffmpeg.org/download.html).
- **Zsh Shell**: Script is written in Zsh; ensure compatibility.

## Credits

- Developed by GPT-4o and Claude Sonnet 3.5 (including this readme).