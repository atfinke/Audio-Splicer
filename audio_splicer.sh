#!/bin/zsh

set -e

# Function to display script usage
usage() {
    echo "Usage: $0 -i <input_file> [-d <max_splice_duration>] [-o <output_directory>] [-w] [-v]"
    echo "  -i: Input audio file path (required)"
    echo "  -d: Maximum splice duration in minutes (optional, default: 10)"
    echo "  -o: Output directory (optional, default: same as input file)"
    echo "  -w: Water MP3 player mode (optional)"
    echo "  -v: Verbose mode"
    exit 1
}

# Default values
max_splice_duration=10  # default value in minutes
water_mp3_player_mode=false
verbose=false

# Parse command line arguments
while getopts ":i:d:o:wv" opt; do
    case $opt in
        i) input_file="$OPTARG" ;;
        d) max_splice_duration="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        w) water_mp3_player_mode=true ;;
        v) verbose=true ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
    esac
done

# Check if input file is provided and exists
if [ -z "$input_file" ] || [ ! -f "$input_file" ]; then
    echo "Error: Input file is required and must exist."
    usage
fi

# Convert max_splice_duration to seconds
max_splice_duration=$((max_splice_duration * 60))

# Set output directory if not provided
if [ -z "$output_dir" ]; then
    output_dir=$(dirname "$input_file")
fi

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Display settings
echo "Input file: $input_file"
echo "Output directory: $output_dir"
echo "Max splice duration: $((max_splice_duration / 60)) minutes"
echo "Water MP3 player mode: $water_mp3_player_mode"
echo "Verbose mode: $verbose"

# Function to create silence
create_silence() {
    local duration=$1
    local output_file=$2
    ffmpeg -nostdin -f lavfi -i anullsrc=r=44100:cl=stereo -t "$duration" -q:a 9 -acodec libmp3lame "$output_file" -y > /dev/null 2>&1
}

# Function to create track announcement using macOS 'say' command
create_announcement() {
    local track_num=$1
    local total_tracks=$2
    local output_file="${output_dir}/track_${track_num}_of_${total_tracks}.m4a"
    say "Track $track_num of $total_tracks" -o "$output_file"
    echo "$output_file"
}

# Process each split sequentially
total_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file") || {
    echo "Error: Failed to get total duration of input file."
    exit 1
}
total_duration=${total_duration%.*}  # Remove decimal part
echo "Total duration: $total_duration seconds"

# Calculate number of splits
num_splits=$(( (total_duration + max_splice_duration - 1) / max_splice_duration ))
echo "Number of splits: $num_splits"

# Process each split sequentially
for (( i=1; i<=num_splits; i++ )); do
    echo "\n--- Processing split $i of $num_splits ---"
    start_time=$(( (i-1) * max_splice_duration ))
    duration=$(( total_duration - start_time ))
    if [ "$duration" -gt "$max_splice_duration" ]; then
        duration=$max_splice_duration
    fi
    echo "Start time: $start_time, Duration: $duration seconds"

    # Create track announcement
    track_announcement=$(create_announcement "$i" "$num_splits")

    # Create silence file for 1 second
    announcement_silence="${output_dir}/announcement_silence_1s.mp3"
    create_silence 1 "$announcement_silence"

    # Create ffmpeg command
    ffmpeg_cmd="ffmpeg -nostdin -hide_banner -loglevel error -ss $start_time -t $duration -i \"$input_file\""
    ffmpeg_cmd+=" -i \"$track_announcement\" -i \"$announcement_silence\""
    filter_complex="[1][2]concat=n=2:v=0:a=1[announcement];[announcement][0]concat=n=2:v=0:a=1[audio]"

    # Adjust quality settings based on water MP3 player mode
    if $water_mp3_player_mode; then
        filter_complex+="; [audio]aformat=sample_fmts=s16:sample_rates=22050:channel_layouts=mono,highpass=f=200,compand=gain=-5[filtered_audio]"
        ffmpeg_cmd+=" -filter_complex \"$filter_complex\" -map \"[filtered_audio]\" -acodec libmp3lame -b:a 32k"
    else
        ffmpeg_cmd+=" -filter_complex \"$filter_complex\" -map \"[audio]\" -acodec libmp3lame -q:a 2"
    fi

    # Set output file
    base_name=$(basename "$input_file" .${input_file##*.})
    output_file="${output_dir}/${base_name}_track_${i}_of_${num_splits}.mp3"
    ffmpeg_cmd+=" \"$output_file\" -y"

    # Execute ffmpeg command
    if $verbose; then
        echo "Running: $ffmpeg_cmd"
    fi
    eval "$ffmpeg_cmd"

    echo "Created split $i: $output_file"
    echo "Verifying output file..."
    output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_file") || {
        echo "Error: Failed to get duration of output file $output_file."
        exit 1
    }
    output_duration=${output_duration%.*}
    echo "Output file duration: $output_duration seconds"

    # Clean up track announcement and silence files
    rm "$track_announcement" "$announcement_silence"

    echo "Overall progress: $((100 * i / num_splits))%"
done

echo "\nAudio splitting complete. Output files are in $output_dir"

# Open output directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$output_dir"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$output_dir"
fi
