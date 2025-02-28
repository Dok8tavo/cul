// MIT License
//
// Copyright (c) 2025 Dok8tavo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Byte = @Type(.{ .int = .{
    .bits = std.mem.byte_size_in_bits,
    .signedness = .unsigned,
} });

pub const With = struct {
    iteration: Iteration = .foreward,
    compression: Compression = .cheap,
};

pub const Iteration = enum {
    /// Foreward iteration will cause the cul to store the variants as `tag + payload`, enabling to
    /// iterate over them first-in-first-out, using `Iterator.next`.
    foreward,
    /// Backward iteration will cause the cul to store the variants as `payload + tag`, enabling to
    /// iterate over them first-in-last-out, using `Iterator.prev`.
    backward,
    /// Bothward iteration will cause the cul to store the variants as `tag + payload + tag`,
    /// enabling to iterate over them both first-in-first-out and first-in-last-out, using
    /// `Iterator.next` and `Iterator.prev` respectively.
    bothward,

    pub fn direction(comptime iteration: Iteration) Direction {
        return switch (iteration) {
            .foreward => .foreward,
            .backward => .backward,
            .bothward => @compileError(
                \\There's no default direction when using bothward iteration.
                \\Try using a `Dir` version of the function, or either foreward or backward
            ++ " iteration."),
        };
    }
};

/// When indexing the bytes of a slice, does the index represents the start or the end.
pub const Direction = enum {
    /// The byte index refers to the starting byte (the first byte)
    foreward,
    /// The byte index refers to the ending byte (the byte after the last byte)
    backward,

    pub fn reverse(comptime dir: Direction) Direction {
        return switch (dir) {
            .foreward => .backward,
            .backward => .foreward,
        };
    }
};

pub const Compression = struct {
    /// This function returns the byte size of the type when compressed
    compressedSizeOfFn: fn (comptime T: type) comptime_int,
    /// This function should assert that `buffer.len == compressedSizeOf(@TypeOf(value))`
    compressFn: fn (value: anytype, buffer: []Byte) void,
    /// This function should assert that `value.len == compressedSizeOf(@TypeOf(buffer.*))`
    decompressFn: fn (
        comptime T: type,
        value: []const Byte,
        /// This buffer is of type `*align(1) T`
        buffer: anytype,
    ) void,

    /// Cheap compression only uses pointer casting as a mean to store a type into bytes. It
    /// doesn't do any additional compression.
    pub const cheap = Compression{
        .compressedSizeOfFn = cheapSizeOf,
        .compressFn = cheapCompress,
        .decompressFn = cheapDecompress,
    };

    pub fn compress(
        comptime compression: Compression,
        comptime T: type,
        value: T,
        buffer: *[compression.compressedSizeOf(T)]Byte,
    ) void {
        return compression.compressFn(value, buffer);
    }

    pub fn decompress(
        comptime compression: Compression,
        comptime T: type,
        value: *const [compression.compressedSizeOf(T)]Byte,
    ) T {
        var buffer: T = undefined;
        compression.decompressFn(T, @ptrCast(value), &buffer);
        return buffer;
    }

    pub fn compressedSizeOf(comptime compression: Compression, comptime T: type) comptime_int {
        return compression.compressedSizeOfFn(T);
    }

    fn cheapSizeOf(comptime T: type) comptime_int {
        const bit_size = @bitSizeOf(T);
        const has_bit_padding = bit_size % std.mem.byte_size_in_bits != 0;
        const bit_padding: comptime_int = @intFromBool(has_bit_padding);
        return bit_padding + bit_size / std.mem.byte_size_in_bits;
    }

    fn cheapCompress(value: anytype, buffer: []Byte) void {
        const Value = @TypeOf(value);
        cleanCheapCompress(Value, value, buffer[0..cheapSizeOf(Value)]);
    }

    fn cheapDecompress(comptime T: type, value: []const Byte, buffer: anytype) void {
        buffer.* = cleanCheapDecompress(T, value[0..cheapSizeOf(T)]);
    }

    fn cleanCheapDecompress(comptime T: type, value: *const [cheapSizeOf(T)]Byte) T {
        const ptr: *align(1) const T = @ptrCast(value);
        return ptr.*;
    }

    fn cleanCheapCompress(comptime T: type, value: T, buffer: *[cheapSizeOf(T)]Byte) void {
        const ptr: *const [cheapSizeOf(T)]Byte = @ptrCast(&value);
        @memcpy(buffer, ptr);
    }
};

pub fn CompactUnionList(comptime U: type, comptime with_options: With) type {
    return struct {
        bytes: std.ArrayListUnmanaged(Byte) = .{},

        const Cul = @This();

        const comp = with.compression;
        const iter = with.iteration;

        pub const with = with_options;
        pub const tag_size = with.compression.compressedSizeOfFn(Tag);

        pub const Union = U;
        pub const Tag = std.meta.Tag(Union);

        pub const SizeError = error{ CurrentPayloadTooBig, CurrentPayloadTooSmall };
        pub const TagError = error{WrongTag};

        pub const Iterator = IteratorDir(iter.direction());

        /// Initialize with capacity of `num` bytes. Deinitialize with `deinit`.
        pub fn initBytesCapacity(allocator: Allocator, num: usize) Allocator.Error!Cul {
            return Cul{ .bytes = try .initCapacity(allocator, num) };
        }

        /// Release all allocated memory.
        pub fn deinit(cul: *Cul, allocator: Allocator) void {
            cul.bytes.deinit(allocator);
            cul.* = undefined;
        }

        /// Extend the list by 1 element. Allocates more memory as necessary.
        /// Invalidates element pointers if additional memory is needed.
        pub fn append(cul: *Cul, allocator: Allocator, u: Union) Allocator.Error!void {
            switch (u) {
                inline else => |payload, comptime_tag| {
                    const size = comptime variantSize(comptime_tag);
                    const index = cul.bytes.items.len +
                        if (iter == .backward) size else 0;
                    _ = try cul.bytes.addManyAsArray(allocator, size);
                    cul.setVariantUncheckedDir(
                        if (iter == .backward) .backward else .foreward,
                        comptime_tag,
                        payload,
                        index,
                    );
                },
            }
        }

        pub fn iterateDir(cul: *const Cul, comptime dir: Direction) IteratorDir(dir) {
            return .init(cul);
        }

        pub fn iterate(cul: *const Cul) Iterator {
            return .init(cul);
        }

        pub fn IteratorDir(comptime dir: Direction) type {
            return struct {
                cul: *const Cul,
                idx: usize,

                const CulIterator = @This();

                pub const Reverse = IteratorDir(dir.reverse());

                pub fn init(cul: *const Cul) CulIterator {
                    return CulIterator{
                        .cul = cul,
                        .idx = switch (dir) {
                            .backward => cul.bytes.items.len,
                            .foreward => 0,
                        },
                    };
                }

                pub fn next(it: *CulIterator) ?Union {
                    return if (it.peek()) |u| {
                        it.skip();
                        return u;
                    } else null;
                }

                pub fn skip(it: *CulIterator) void {
                    const tag = it.cul.getTagDir(dir, it.idx);
                    const len = switch (tag) {
                        inline else => |comptime_tag| variantSize(comptime_tag),
                    };

                    it.idx = switch (dir) {
                        .backward => it.idx - len,
                        .foreward => it.idx + len,
                    };
                }

                pub fn peek(it: CulIterator) ?Union {
                    if (it.ended())
                        return null;
                    return it.cul.getDir(dir, it.idx);
                }

                pub fn ended(it: CulIterator) bool {
                    return it.idx == switch (dir) {
                        .backward => 0,
                        .foreward => it.cul.bytes.items.len,
                    };
                }

                pub fn reverse(it: CulIterator) Reverse {
                    return Reverse{
                        .cul = it.cul,
                        .idx = it.idx,
                    };
                }
            };
        }

        /// This function resolves the index of the nth element, starting with the zeroth element,
        /// then oneth, twoth, threeth, etc.
        pub fn resolveIndex(cul: Cul, nth: usize) ?usize {
            return cul.resolveIndexDir(iter.direction(), nth);
        }

        /// This function resolves the index of the nth element, starting with the zeroth element,
        /// then oneth, twoth, threeth, etc.
        pub fn resolveIndexDir(cul: Cul, comptime dir: Direction, nth: usize) ?usize {
            var it = cul.iterateDir(dir);
            var n = nth;

            while (n != 0) : (n -= 1)
                if (it.next() == null)
                    break;

            return if (it.ended()) null else it.idx;
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a variant of the same size as the given `u: Union`.
        pub fn set(cul: Cul, u: Union, variant_index: usize) SizeError!void {
            try cul.setDir(iter.direction(), u, variant_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a variant of the same size as the given `u: Union`.
        pub fn setDir(
            cul: Cul,
            comptime dir: Direction,
            u: Union,
            variant_index: usize,
        ) SizeError!void {
            switch (u) {
                inline else => |payload, comptime_tag| try cul.setVariantDir(
                    dir,
                    comptime_tag,
                    payload,
                    variant_index,
                ),
            }
        }

        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a variant of the same size as the given `u: Union`.
        pub fn setUnchecked(cul: Cul, u: Union, variant_index: usize) void {
            cul.setUncheckedDir(iter.direction(), u, variant_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a variant of the same size as the given `u: Union`.
        pub fn setUncheckedDir(
            cul: Cul,
            comptime dir: Direction,
            u: Union,
            variant_index: usize,
        ) void {
            switch (u) {
                inline else => |payload, comptime_tag| cul.setVariantUncheckedDir(
                    dir,
                    comptime_tag,
                    payload,
                    variant_index,
                ),
            }
        }

        /// This function assumes that the `byte_index` is a valid byte index.
        pub fn get(cul: Cul, variant_index: usize) Union {
            return cul.getDir(iter.direction(), variant_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index.
        pub fn getDir(cul: Cul, comptime dir: Direction, variant_index: usize) Union {
            const tag = cul.getTagDir(dir, variant_index);
            const payload_index = payloadIndexDir(dir, variant_index);
            return switch (tag) {
                inline else => |comptime_tag| @unionInit(
                    Union,
                    @tagName(comptime_tag),
                    cul.getPayloadUncheckedDir(dir, comptime_tag, payload_index),
                ),
            };
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn setVariant(
            cul: Cul,
            comptime tag: Tag,
            payload: Payload(tag),
            variant: usize,
        ) SizeError!void {
            try cul.setVariantDir(iter.direction(), tag, payload, variant);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn setVariantDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload: Payload(tag),
            variant_index: usize,
        ) SizeError!void {
            try cul.checkSize(tag, variant_index);
            cul.setVariantUncheckedDir(dir, tag, payload, variant_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload of the same size as the given payload.
        pub fn setVariantUnchecked(
            cul: Cul,
            comptime tag: Tag,
            payload: Payload(tag),
            variant_index: usize,
        ) void {
            cul.setVariantUncheckedDir(iter.direction(), tag, payload, variant_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload of the same size as the given payload.
        pub fn setVariantUncheckedDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload: Payload(tag),
            variant_index: usize,
        ) void {
            const payload_index = payloadIndexDir(dir, variant_index);
            cul.setTagUncheckedDir(dir, tag, variant_index);
            cul.setPayloadUncheckedDir(dir, tag, payload, payload_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn checkTag(cul: Cul, comptime tag: Tag, tag_index: usize) TagError!void {
            return cul.checkTagDir(iter.direction(), tag, tag_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn checkTagDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            tag_index: usize,
        ) TagError!void {
            const current_tag = cul.getTagDir(dir, tag_index);
            if (current_tag != tag)
                return TagError.WrongTag;
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a similarily-tagged payload as the given payload.
        pub fn setPayload(
            cul: Cul,
            comptime tag: Tag,
            payload: Payload(tag),
            payload_index: usize,
        ) TagError!void {
            cul.setPayloadDir(iter.direction(), tag, payload, payload_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a similarily-tagged payload as the given payload.
        pub fn setPayloadDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload: Payload(tag),
            payload_index: usize,
        ) void {
            const tag_index = tagIndexDir(dir, payload_index);
            try cul.checkTagDir(dir, tag, tag_index);
            cul.setPayloadUncheckedDir(dir, tag, payload, payload_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a similarily-tagged payload as the given payload.
        pub fn setPayloadUnchecked(
            cul: Cul,
            comptime tag: Tag,
            payload: Payload(tag),
            payload_index: usize,
        ) void {
            cul.setPayloadUncheckedDir(iter.direction(), tag, payload, payload_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a similarily-tagged payload as the given payload.
        pub fn setPayloadUncheckedDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload: Payload(tag),
            payload_index: usize,
        ) void {
            cul.setTypeDir(dir, Payload(tag), payload, payload_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload tagged by the given `tag`.
        pub fn getPayload(
            cul: Cul,
            comptime tag: Tag,
            payload_index: usize,
        ) TagError!Payload(tag) {
            return try cul.getPayloadDir(iter.direction(), tag, payload_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload tagged by the given `tag`.
        pub fn getPayloadDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload_index: usize,
        ) TagError!Payload(tag) {
            const tag_index = tagIndexDir(dir, payload_index);
            try cul.checkTagDir(dir, tag, tag_index);
            return cul.getPayloadUncheckedDir(dir, tag, payload_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload tagged by the given `tag`.
        pub fn getPayloadUnchecked(cul: Cul, comptime tag: Tag, payload_index: usize) Payload(tag) {
            return cul.getPayloadUncheckedDir(iter.direction(), tag, payload_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload tagged by the given `tag`.
        pub fn getPayloadUncheckedDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            payload_index: usize,
        ) Payload(tag) {
            return cul.getTypeDir(dir, Payload(tag), payload_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn checkSize(cul: Cul, comptime candidate_tag: Tag, tag_index: usize) SizeError!void {
            return cul.checkSizeDir(iter.direction(), candidate_tag, tag_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload.
        pub fn checkSizeDir(
            cul: Cul,
            comptime dir: Direction,
            comptime candidate_tag: Tag,
            tag_index: usize,
        ) SizeError!void {
            const current_tag = cul.getTagDir(dir, tag_index);
            switch (current_tag) {
                inline else => |comptime_current_tag| {
                    const current_size = variantSize(comptime_current_tag);
                    const candidate_size = variantSize(candidate_tag);

                    if (candidate_size < current_size)
                        return SizeError.CurrentPayloadTooBig;

                    if (current_size < candidate_size)
                        return SizeError.CurrentPayloadTooSmall;
                },
            }
        }

        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload. Accessing
        /// the payload just after calling this function is undefined behavior.
        pub fn setTag(cul: Cul, comptime tag: Tag, tag_index: usize) SizeError!void {
            try cul.setTagDir(iter.direction(), tag, tag_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index. It checks whether
        /// the location is occupied by a payload of the same size as the given payload. Accessing
        /// the payload just after calling this function is undefined behavior.
        pub fn setTagDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            tag_index: usize,
        ) SizeError!void {
            try cul.checkSizeDir(dir, tag, tag_index);
            cul.setTagUncheckedDir(dir, tag, tag_index);
        }

        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload of the same size as the given payload. Accessing the
        /// payload just after calling this function is undefined behavior.
        pub fn setTagUnchecked(cul: Cul, comptime tag: Tag, tag_index: usize) void {
            cul.setTagUncheckedDir(iter.direction(), tag, tag_index);
        }
        /// This function assumes that the `byte_index` is a valid byte index, and that the
        /// location is occupied by a payload of the same size as the given payload. Accessing the
        /// payload just after calling this function is undefined behavior.
        pub fn setTagUncheckedDir(
            cul: Cul,
            comptime dir: Direction,
            comptime tag: Tag,
            tag_index: usize,
        ) void {
            cul.setTypeDir(dir, Tag, tag, tag_index);
            if (iter == .bothward and payloadSize(tag) != 0) cul.setTypeDir(dir, Tag, tag, switch (dir) {
                .backward => tag_index - payloadSize(tag) - tag_size,
                .foreward => tag_index + payloadSize(tag) + tag_size,
            });
        }

        /// This function assumes that the given `byte_index` is a valid byte index.
        pub fn getTag(cul: Cul, tag_index: usize) Tag {
            return cul.getTagDir(iter.direction(), tag_index);
        }
        /// This function assumes that the given `byte_index` is a valid byte index.
        pub fn getTagDir(cul: Cul, comptime dir: Direction, tag_index: usize) Tag {
            return cul.getTypeDir(dir, Tag, tag_index);
        }

        /// This function assumes that the given `byte_index` is a valid byte index.
        pub fn getTagBytes(cul: Cul, tag_index: usize) *[tag_size]Byte {
            return cul.getTagBytesDir(iter.direction(), tag_index);
        }
        /// This function assumes that the given `byte_index` is a valid byte index.
        pub fn getTagBytesDir(cul: Cul, comptime dir: Direction, tag_index: usize) *[tag_size]Byte {
            return cul.getTypeBytesDir(dir, Tag, tag_index);
        }

        pub fn setType(cul: Cul, comptime T: type, value: T, index: usize) void {
            cul.setTypeDir(iter.direction(), T, value, index);
        }
        pub fn setTypeDir(
            cul: Cul,
            comptime dir: Direction,
            comptime T: type,
            value: T,
            index: usize,
        ) void {
            comp.compress(T, value, cul.getTypeBytesDir(dir, T, index));
        }

        pub fn getType(cul: Cul, comptime T: type, index: usize) T {
            return cul.getTypeDir(iter.direction(), T, index);
        }
        pub fn getTypeDir(cul: Cul, comptime dir: Direction, comptime T: type, index: usize) T {
            return comp.decompress(T, cul.getTypeBytesDir(dir, T, index));
        }

        pub fn getTypeBytes(cul: Cul, comptime T: type, index: usize) *[comp.compressedSizeOf(T)]Byte {
            return cul.getTypeBytesDir(iter.direction(), T, index);
        }
        pub fn getTypeBytesDir(
            cul: Cul,
            comptime dir: Direction,
            comptime T: type,
            index: usize,
        ) *[comp.compressedSizeOf(T)]Byte {
            return cul.getBytesArrayDir(dir, index, comp.compressedSizeOf(T));
        }

        pub fn getBytesArray(cul: Cul, index: usize, comptime len: usize) *[len]Byte {
            return cul.getBytesArrayDir(iter.direction(), index, len);
        }
        pub fn getBytesArrayDir(
            cul: Cul,
            comptime dir: Direction,
            byte_index: usize,
            comptime len: usize,
        ) *[len]Byte {
            checkDir(dir);
            return switch (dir) {
                .foreward => cul.bytes.items[byte_index..][0..len],
                .backward => cul.bytes.items[byte_index - len ..][0..len],
            };
        }

        pub fn getBytesSlice(cul: Cul, index: usize, len: usize) []Byte {
            return cul.getBytesSliceDir(iter.direction(), index, len);
        }
        pub fn getBytesSliceDir(
            cul: Cul,
            comptime dir: Direction,
            index: usize,
            len: usize,
        ) []Byte {
            checkDir(dir);
            return switch (dir) {
                .foreward => cul.bytes.items[index .. index + len],
                .backward => cul.bytes.items[index - len .. index],
            };
        }

        /// The variant size represents the byte size of the compressed payload and tag(s) combined
        /// . For only the payload see `payloadSize`.
        pub fn variantSize(comptime tag: Tag) usize {
            const payload = comptime payloadSize(tag);
            const second_tag: usize =
                @intFromBool(iter == .bothward and payload != 0);
            return payload + tag_size * (1 + second_tag);
        }

        /// The payload size represents the byte size of the compressed payload. It doesn't take
        /// the tag into account. For this see `variantSize`.
        pub fn payloadSize(comptime tag: Tag) usize {
            return comp.compressedSizeOf(Payload(tag));
        }

        pub fn Payload(comptime tag: Tag) type {
            return @FieldType(Union, @tagName(tag));
        }

        /// This function takes in the index of a tag (or variant) and returns the index of the
        /// corresponding payload.
        pub fn payloadIndex(tag_index: usize) usize {
            return payloadIndexDir(iter.direction(), tag_index);
        }

        /// This function takes in the index of a tag (or variant) and returns the index of the
        /// corresponding payload.
        pub fn payloadIndexDir(comptime dir: Direction, tag_index: usize) usize {
            return switch (dir) {
                // |tag_index| TAG(tag_size) |payload_index| PAYLOAD(...) |...| ...
                .foreward => tag_index + tag_size,
                // ... |...| PAYLOAD(...) |payload_index| TAG(tag_size) |tag_index|
                .backward => tag_index - tag_size,
            };
        }

        /// This function takes in the index of a payload and returns the index of the
        /// corresponding tag (or variant).
        pub fn tagIndex(payload_index: usize) usize {
            return tagIndexDir(iter.direction(), payload_index);
        }

        /// This function takes in the index of a payload and returns the index of the
        /// corresponding tag (or variant).
        pub fn tagIndexDir(comptime dir: Direction, payload_index: usize) usize {
            return switch (dir) {
                // |tag_index| TAG(tag_size) |payload_index| PAYLOAD(...) |...| ...
                .foreward => payload_index - tag_size,
                // ... |...| PAYLOAD(...) |payload_index| TAG(tag_size) |tag_index|
                .backward => payload_index + tag_size,
            };
        }

        inline fn checkDir(comptime dir: Direction) void {
            const is_wrong = switch (dir) {
                .backward => iter == .foreward,
                .foreward => iter == .backward,
            };

            if (is_wrong) @compileError(std.fmt.comptimePrint(
                "Can't use direction `.{s}` when iteration is `.{s}`!",
                .{ @tagName(dir), @tagName(iter) },
            ));
        }
    };
}

test "all tests" {
    _ = @import("tests.zig");
}
