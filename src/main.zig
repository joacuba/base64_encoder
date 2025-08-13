const std = @import("std");
const clap = @import("clap");

const Base64 = struct {
    _lookup_table: []const u8,
    pad_char: u8 = '=',
    _encode: ?[]u8 = null,
    _decode: ?[]u8 = null,
    _allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_symb = "0123456789+/";
        return Base64{
            ._lookup_table = upper ++ lower ++ numbers_symb,
            ._allocator = allocator,
        };
    }

    pub fn deinit(self: *const Base64) void {
        // orelse unreachable is equivalent to .? (optional unwrap operator)
        if (self._encode != null) self._allocator.free(self._encode orelse unreachable);
        if (self._decode != null) self._allocator.free(self._decode.?);
    }

    fn _char_at(self: *const Base64, index: u8) u8 {
        return self._lookup_table[index];
    }

    fn _char_index(self: *const Base64, char: u8) u8 {
        if (char == self.pad_char) return 64;
        var index: u8 = 0;
        while (index < 63) : (index += 1) {
            if (self._lookup_table[index] == char) break;
        }
        return index;
    }

    pub fn encode(self: *Base64, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_out_bytes = try calc_encode_len(input);
        // Get slice with encode_len from array created in memory with alloc method;
        var encode_msg = try self._allocator.alloc(u8, n_out_bytes);
        var buf_window = [_]u8{ 0, 0, 0 };
        var i_bw: u8 = 0;
        var iter_out: u64 = 0;
        for (input) |byte| {
            buf_window[i_bw] = byte;
            i_bw += 1;
            if (i_bw == 3) {
                encode_msg[iter_out] = self._char_at(buf_window[0] >> 2);
                encode_msg[iter_out + 1] = self._char_at(((buf_window[0] & 0x03) << 4) + (buf_window[1] >> 4));
                encode_msg[iter_out + 2] = self._char_at(((buf_window[1] & 0x0f) << 2) + (buf_window[2] >> 6));
                encode_msg[iter_out + 3] = self._char_at(buf_window[2] & 0x3f);
                i_bw = 0;
                iter_out += 4;
            }
        }

        if (i_bw == 2) {
            encode_msg[iter_out] = self._char_at(buf_window[0] >> 2);
            encode_msg[iter_out + 1] = self._char_at(((buf_window[0] & 0x03) << 4) + (buf_window[1] >> 4));
            encode_msg[iter_out + 2] = self._char_at((buf_window[0] & 0x0f) << 2);
            encode_msg[iter_out + 3] = self.pad_char;
        }

        if (i_bw == 1) {
            encode_msg[iter_out] = self._char_at(buf_window[0] >> 2);
            encode_msg[iter_out + 1] = self._char_at((buf_window[0] & 0x03) << 4);
            encode_msg[iter_out + 2] = self.pad_char;
            encode_msg[iter_out + 3] = self.pad_char;
        }
        self._encode = encode_msg;
        return encode_msg;
    }

    pub fn decode(self: *Base64, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_out_bytes = try calc_decode_len(input);
        // Slice get form allococator
        const decode_msg = try self._allocator.alloc(u8, n_out_bytes);
        var buf_window = [_]u8{ 0, 0, 0, 0 };
        var iter_bw: u3 = 0;
        var iter_decode_msg: u64 = 0;
        for (input) |byte| {
            buf_window[iter_bw] = self._char_index(byte);
            iter_bw += 1;
            if (iter_bw == 4) {
                decode_msg[iter_decode_msg] = (buf_window[0] << 2) + (buf_window[1] >> 4);
                if (buf_window[2] != 64) decode_msg[iter_decode_msg + 1] = (buf_window[1] << 4) + (buf_window[2] >> 2);
                if (buf_window[3] != 64) decode_msg[iter_decode_msg + 2] = (buf_window[2] << 6) + buf_window[3];
                iter_decode_msg += 3;
                iter_bw = 0;
            }
        }
        self._decode = decode_msg;
        return decode_msg;
    }
};

pub fn calc_encode_len(input: []const u8) !usize {
    if (input.len <= 3) return 4;
    const n_groups_3bytes = try std.math.divCeil(usize, input.len, 3);
    return n_groups_3bytes * 4;
}

pub fn calc_decode_len(input: []const u8) !usize {
    var n_groups_4bytes: usize = undefined;
    if (input.len <= 4) n_groups_4bytes = 4 else {
        n_groups_4bytes = try std.math.divFloor(usize, input.len, 4);
    }

    var out_bytes = n_groups_4bytes * 3;
    var i: usize = input.len - 1;
    while (i > 0) : (i -= 1) {
        if (input[i] == '=') out_bytes -= 1 else break;
    }
    return out_bytes;
}

pub fn main() !void {
    const out = std.io.getStdOut();
    var buff_out = std.io.bufferedWriter(out.writer());
    const writer = buff_out.writer();

    var dbg_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg_alloc.deinit();
    const allocator = dbg_alloc.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-e, --encode <str>     Encode the provided string using base64 encoder (default behavior).
        \\-d, --decode <str>     Decode the provided string using base64 encoder.
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.report(std.io.getStdErr().writer(), err);
        return err;
    };
    defer res.deinit();

    var base64 = Base64.init(allocator);
    defer base64.deinit();

    var str_input = std.ArrayList(u8).init(allocator);
    defer str_input.deinit();

    var mode_switch: bool = true;

    if (res.args.help != 0) {
        try clap.help(writer, clap.Help, &params, .{});
        return buff_out.flush();
    }
    if (res.args.encode) |s| {
        try str_input.appendSlice(s);
    }
    if (res.args.decode) |s| {
        try str_input.appendSlice(s);
        mode_switch = false;
    }
    for (res.positionals[0]) |pos| {
        if (!mode_switch) {
            try str_input.appendSlice(pos);
        } else {
            try str_input.appendSlice(pos);
        }
    }

    const str_input_slice = try str_input.toOwnedSlice();
    defer allocator.free(str_input_slice);
    var output: ?[]u8 = null;
    if (!mode_switch) {
        output = try base64.decode(str_input_slice);
    } else if (mode_switch) {
        output = try base64.encode(str_input_slice);
    }

    try writer.print("{s}\n", .{output.?});

    try buff_out.flush();
}

test "encode" {
    var dbg_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg_alloc.deinit();
    const allocator = dbg_alloc.allocator();
    var base64 = Base64.init(allocator);
    defer base64.deinit();
    const text_to_encode = "Testing some more stuff";
    const text_to_decode = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const result_encode = try base64.encode(text_to_encode);
    try std.testing.expectEqualStrings(text_to_decode, result_encode);
}

test "decode" {
    var dbg_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg_alloc.deinit();
    const allocator = dbg_alloc.allocator();
    var base64 = Base64.init(allocator);
    defer base64.deinit();
    const text_to_encode = "Testing some more stuff";
    const text_to_decode = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const result_decode = try base64.decode(text_to_decode);
    try std.testing.expectEqualStrings(text_to_encode, result_decode);
}
