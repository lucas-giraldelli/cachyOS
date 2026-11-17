function frame --description 'Save a video frame as a PNG with the colors a player shows'
    # Usage: frame <file | search> <time> [count]
    #   frame 'south park s03e01' 2:16      one frame at 2:16
    #   frame 'south park s03e01' 2:16 8    8 frames spread over the 2 seconds around 2:16
    #   frame --south-park-s03e01 2:16      the same search as a flag (dashes become spaces)
    #   frame ~/video.mkv 1:02:03
    # A search is looked up in the media library: every word must appear in the path.
    # Frames go to ~/Downloads/frames/.
    if test (count $argv) -lt 2
        echo 'usage: frame <file | search> <time> [count]' >&2
        return 1
    end

    set -l src $argv[1]
    set -l at $argv[2]
    set -l n 1
    test (count $argv) -ge 3; and set n $argv[3]

    # --south-park-s03e01 is shorthand for the search 'south park s03e01'.
    if string match -q -- '--*' $src
        set src (string replace -a -- '-' ' ' (string sub -s 3 -- $src))
    end

    if not test -f "$src"
        set -l matches (find /mnt/main/Media-Stack/data/media -type f \
            \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' \) 2>/dev/null)
        for word in (string split -n ' ' -- $src)
            set matches (string match -ie -- $word $matches)
        end
        if test (count $matches) -eq 0
            echo "frame: nothing in the media library matches '$src'" >&2
            return 1
        else if test (count $matches) -gt 1
            echo "frame: '$src' matches more than one file:" >&2
            printf '  %s\n' $matches >&2
            return 1
        end
        set src $matches[1]
    end

    # Many rips leave the color space untagged, and ffmpeg then converts with BT.601,
    # which shifts the colors away from what players show (they assume BT.709 for HD).
    # Force BT.709, expand the limited TV range and write an ordinary 8-bit PNG.
    set -l color 'scale=in_color_matrix=bt709:in_range=tv:out_range=pc:flags=accurate_rnd+full_chroma_int,format=rgb24'

    set -l outdir ~/Downloads/frames
    mkdir -p $outdir
    set -l name (path change-extension '' (path basename -- $src))_(string replace -a ':' '.' -- $at)

    if test "$n" -le 1
        set -l out $outdir/$name.png
        ffmpeg -hide_banner -loglevel error -y -ss $at -i $src -frames:v 1 -vf $color $out
        or return
        echo $out
    else
        # Start one second early so the requested time sits in the middle.
        set -l secs 0
        for part in (string split ':' -- $at)
            set secs (math "$secs * 60 + $part")
        end
        set -l start (math "max(0, $secs - 1)")
        set -l fps (math "$n / 2")
        ffmpeg -hide_banner -loglevel error -y -ss $start -i $src -t 2 \
            -vf "fps=$fps,$color" -frames:v $n $outdir/$name"_%02d.png"
        or return
        printf '%s\n' $outdir/$name"_"*.png
    end
end
