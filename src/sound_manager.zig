const std = @import("std");
const c = @import("c.zig");

const Error = error{
    SoundManagerInitFailed,
    DecodeAudio,
    DeviceInit,
    DeviceStart,
    PlaySound,
    ContextInit,
    DeviceEnumeration,
};

pub const Sound = enum(usize) {
    Jump,
    Step,
    Song,
};

const DecodedFrames = struct {
    frame_count: u64,
    frames: ?*anyopaque,
};

const PlayingSound = struct {
    sound: Sound,
    loop: bool,
    buffer: c.ma_audio_buffer,
};

const SAMPLE_FORMAT = c.ma_format_f32;
const CHANNEL_COUNT = 2;
const SAMPLE_RATE = 48000;
const MAX_CONCURRENT_SOUNDS = 100;

// raw, decoded audio data lookup
var decoded: [std.enums.values(Sound).len]DecodedFrames = undefined;
var device: c.ma_device = undefined;
var playing = [_]?PlayingSound{null} ** MAX_CONCURRENT_SOUNDS;

export fn dataCallback(_: [*c]c.ma_device, out: ?*anyopaque, _: ?*const anyopaque, frame_count: c_uint) void {
    // TODO (etate): mix PCM frames in a temp buffer and flush them to the output
    // var mix_buffer = std.mem.zeroes([4096]f32);

    for (playing) |*opt_sound, idx| {
        if (opt_sound.*) |*sound| {
            const frames_read = c.ma_audio_buffer_read_pcm_frames(&sound.buffer, out, frame_count, @boolToInt(false));
            // when we reach the end, set to inactive
            if (frames_read <= frame_count) {
                if (sound.loop) {
                    loop(sound.sound) catch unreachable;
                } else {
                    playing[idx] = null;
                }
            }
        }
    }
}

fn soundToPath(snd: Sound) [*c]const u8 {
    return switch (snd) {
        .Jump => "./assets/sounds/jump.ogg",
        .Step => "./assets/sounds/step.ogg",
        .Song => "./assets/sounds/song.ogg",
    };
}

pub fn init() Error!void {
    // init audio context
    var context: c.ma_context = undefined;
    if (c.ma_context_init(null, 0, null, &context) != c.MA_SUCCESS) {
        return Error.ContextInit;
    }

    var playbackInfos: [*c]c.ma_device_info = undefined;
    var playbackCount: u32 = 0;
    if (c.ma_context_get_devices(&context, &playbackInfos, &playbackCount, null, null) != c.MA_SUCCESS) {
        return Error.DeviceEnumeration;
    }

    var idx: usize = 0;
    while (idx < playbackCount) : (idx += 1) {
        std.debug.print("{d} - {s}\n", .{ idx, playbackInfos[idx].name });
    }

    // init audio device
    var cfg = c.ma_device_config_init(c.ma_device_type_playback);
    cfg.playback.format = SAMPLE_FORMAT;
    cfg.playback.channels = CHANNEL_COUNT;
    cfg.sampleRate = SAMPLE_RATE;
    cfg.dataCallback = dataCallback;
    cfg.pUserData = null;

    var res = c.ma_device_init(null, &cfg, &device);
    if (res != c.MA_SUCCESS) {
        std.debug.print("Failure code: {d}\n", .{res});
        return Error.DeviceInit;
    }

    std.debug.print("Inititialized device\n", .{});
    if (c.ma_device_start(&device) != c.MA_SUCCESS) {
        return Error.DeviceStart;
    }

    // initialize all audio data
    for (std.enums.values(Sound)) |val| {
        // var buf_cfg: c.ma_decoder_config = undefined;
        // buf_cfg.format = SAMPLE_FORMAT;
        // buf_cfg.channels = CHANNEL_COUNT;
        // buf_cfg.sampleRate = SAMPLE_RATE;

        const path = soundToPath(val);
        std.debug.print("Loading file: {s}\n", .{path});

        var decoded_frames: DecodedFrames = undefined;
        res = c.ma_decode_file(path, null, &decoded_frames.frame_count, &decoded_frames.frames);
        if (res != c.MA_SUCCESS) {
            std.debug.print("failed to load: {s}", .{path});
            return Error.DecodeAudio;
        }
        std.debug.print("Decoded file with frames: {d}\n", .{decoded_frames.frame_count});
        decoded[@enumToInt(val)] = decoded_frames;
    }
}

pub fn free() Error!void {
    c.ma_device_stop(device);
    for (decoded) |*decoder| {
        c.ma_decoder_uninit(decoder);
    }

    c.ma_device_uninit(device);
}

fn playSound(snd: Sound, looping: bool) Error!void {
    const buffer_cfg = c.ma_audio_buffer_config_init(
        SAMPLE_FORMAT,
        CHANNEL_COUNT,
        decoded[@enumToInt(snd)].frame_count,
        decoded[@enumToInt(snd)].frames,
        null,
    );

    var audio_buffer: c.ma_audio_buffer = undefined;
    if (c.ma_audio_buffer_init(&buffer_cfg, &audio_buffer) != c.MA_SUCCESS) {
        return Error.PlaySound;
    }

    for (playing) |opt_sound, idx| {
        if (opt_sound == null) {
            playing[idx] = PlayingSound{
                .sound = snd,
                .loop = looping,
                .buffer = audio_buffer,
            };
        }
    }
}

pub fn play(snd: Sound) Error!void {
    std.debug.print("Playing sound!", .{});
    return playSound(snd, false);
}

pub fn loop(snd: Sound) Error!void {
    return playSound(snd, true);
}
