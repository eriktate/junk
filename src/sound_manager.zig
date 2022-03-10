const std = @import("std");
const c = @import("c.zig");

const Error = error {
    SoundManagerInitFailed,
    DecodeAudio,
    DeviceInit,
    DeviceStart,
    PlaySound,
};

const Sound = enum(usize) {
    Jump,
    Walk,
    Song,
};

const DecodedFrames = struct {
    frame_count: u64,
    frames: [*]u8,
};

const PlayingSound = struct {
    sound: Sound,
    loop: bool,
    buffer: c.ma_audio_buffer,
};

const SAMPLE_FORMAT = c.ma_format_f32;
const CHANNEL_COUNT = 2;
const SAMPLE_RATE = 4800;
const MAX_CONCURRENT_SOUNDS = 100;

// raw, decoded audio data lookup
var decoded: [std.enums.values(Sound).len]DecodedFrames = undefined;
var device: *c.ma_device = undefined;
var playing: [MAX_CONCURRENT_SOUNDS]?PlayingSound = undefined;



fn dataCallback(_: [*c]c.ma_device, out: ?*anyopaque, _: ?*const anyopaque, frame_count: c_uint) void {
    for (playing) |opt_sound| {
        if (opt_sound) |*sound| {
            var frames_read: u64 = 0;
            _ = c.ma_data_source_read_pcm_frames(sound.buffer, out, frame_count, &frames_read);

            // when we reach the end, set to inactive
            if (frames_read < frame_count) {
                if (sound.loop) {
                    sound = loop(sound.sound);
                } else {
                    sound = null;
                }
            }
        }
    }
}

fn soundToPath(snd: Sound) [*c]const u8 {
    return switch (snd) {
        .Jump => "./assets/sounds/jump.ogg",
        .Walk => "./assets/sounds/walk.ogg",
        .Song => "./assets/sounds/song.ogg",
    };
}

pub fn init() Error!void {
    // initialize all audio data
    for (std.enums.values(Sound)) |val| {
        const path = soundToPath(val);
        const decoded_frames: DecodedFrames = undefined;
        const res = c.ma_decode_file(path, null, decoded_frames.frame_count, &decoded_frames.frames);
        if (res != c.MA_SUCCESS) {
            std.debug.print("failed to load: {s}", .{path});
            return Error.DecodeAudio;
        }
        decoded[val] = decoded_frames;
    }

    // init audio device
    var cfg = c.ma_device_config_init(c.ma_device_type_playback);
    cfg.playback.format = SAMPLE_FORMAT;
    cfg.playback.channels = CHANNEL_COUNT;
    cfg.sampleRate = SAMPLE_RATE;
    cfg.dataCallback = dataCallback;
    cfg.pUserData = null;

    if (c.ma_device_init(null, &cfg, &device) != c.MA_SUCCESS) {
        return Error.DeviceInit;
    }

    if (c.ma_device_start(&device) != c.MA_SUCCESS) {
        return Error.DeviceStart;
    }
}

pub fn free() Error!void {
    c.ma_device_stop(device);
    for (decoded) |*decoder| {
        c.ma_decoder_uninit(decoder);
    }

    c.ma_device_uninit(&device);
}

fn playSound(snd: Sound, looping: bool) Error!void {
    const buffer_cfg = c.ma_audio_buffer_config_init(
        SAMPLE_FORMAT,
        CHANNEL_COUNT,
        decoded[snd].frame_count,
        decoded[snd].frames,
    );

    var audio_buffer: c.ma_audio_buffer = undefined;
    if (c.ma_audio_buffer_init(buffer_cfg, &audio_buffer) != c.MA_SUCCESS) {
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
    return playSound(snd, false);
}

pub fn loop(snd: Sound) Error!void {
    return playSound(snd, true);
}
