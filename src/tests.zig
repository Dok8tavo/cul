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

const t = std.testing;
const root = @import("root.zig");

const ta = t.allocator;
const endian = @import("builtin").cpu.arch.endian();
const SByte = @Type(.{ .int = .{
    .bits = @bitSizeOf(UByte),
    .signedness = .signed,
} });

const UByte = root.Byte;
const CompactUnionList = root.CompactUnionList;
const ForCul = CompactUnionList(Union, .{ .iteration = .forward });
const BackCul = CompactUnionList(Union, .{ .iteration = .backward });
const BothCul = CompactUnionList(Union, .{ .iteration = .bothward });

const Union = union(enum) {
    empty,
    byte: UByte,
    signed_byte: SByte,
    float: f32,
    big_int: u256,
    array: [4]UByte,
};

test "Cul.deinit" {
    var cul = try ForCul.initBytesCapacity(ta, 12);
    cul.deinit(ta);
}

test "Cul.payloadSize" {
    try t.expectEqual(0, ForCul.payloadSize(.empty));
    try t.expectEqual(1, ForCul.payloadSize(.byte));
    try t.expectEqual(1, ForCul.payloadSize(.signed_byte));
    try t.expectEqual(4, ForCul.payloadSize(.float));
    try t.expectEqual(32, ForCul.payloadSize(.big_int));
    try t.expectEqual(4, ForCul.payloadSize(.array));

    try t.expectEqual(0, BackCul.payloadSize(.empty));
    try t.expectEqual(1, BackCul.payloadSize(.byte));
    try t.expectEqual(1, BackCul.payloadSize(.signed_byte));
    try t.expectEqual(4, BackCul.payloadSize(.float));
    try t.expectEqual(32, BackCul.payloadSize(.big_int));
    try t.expectEqual(4, BackCul.payloadSize(.array));

    try t.expectEqual(0, BothCul.payloadSize(.empty));
    try t.expectEqual(1, BothCul.payloadSize(.byte));
    try t.expectEqual(1, BothCul.payloadSize(.signed_byte));
    try t.expectEqual(4, BothCul.payloadSize(.float));
    try t.expectEqual(32, BothCul.payloadSize(.big_int));
    try t.expectEqual(4, BothCul.payloadSize(.array));
}

test "Cul.variantSize" {
    try t.expectEqual(1 + 0, ForCul.variantSize(.empty));
    try t.expectEqual(1 + 1, ForCul.variantSize(.byte));
    try t.expectEqual(1 + 1, ForCul.variantSize(.signed_byte));
    try t.expectEqual(1 + 4, ForCul.variantSize(.float));
    try t.expectEqual(1 + 32, ForCul.variantSize(.big_int));
    try t.expectEqual(1 + 4, ForCul.variantSize(.array));

    try t.expectEqual(1 + 0, BackCul.variantSize(.empty));
    try t.expectEqual(1 + 1, BackCul.variantSize(.byte));
    try t.expectEqual(1 + 1, BackCul.variantSize(.signed_byte));
    try t.expectEqual(1 + 4, BackCul.variantSize(.float));
    try t.expectEqual(1 + 32, BackCul.variantSize(.big_int));
    try t.expectEqual(1 + 4, BackCul.variantSize(.array));

    // when the size of the compact payload is 0, there's no need for two tags
    try t.expectEqual(1, BothCul.variantSize(.empty));
    try t.expectEqual(2 + 1, BothCul.variantSize(.byte));
    try t.expectEqual(2 + 1, BothCul.variantSize(.signed_byte));
    try t.expectEqual(2 + 4, BothCul.variantSize(.float));
    try t.expectEqual(2 + 32, BothCul.variantSize(.big_int));
    try t.expectEqual(2 + 4, BothCul.variantSize(.array));
}

test "Cul.tagIndex" {
    // |0| TAG(1) |1| PAYLOAD(...) |...|
    try t.expectEqual(0, ForCul.tagIndex(1));

    // |...| PAYLOAD(...) |5| TAG(1) |6|
    try t.expectEqual(6, BackCul.tagIndex(5));

    // |0| TAG(1) |1| PAYLOAD(4) |5| TAG(1) |6|
    try t.expectEqual(0, BothCul.tagIndexDir(.forward, 1));
    try t.expectEqual(6, BothCul.tagIndexDir(.backward, 5));
}

test "Cul.payloadIndex" {
    // |0| TAG(1) |1| PAYLOAD(...) |...|
    try t.expectEqual(1, ForCul.payloadIndex(0));

    // |...| PAYLOAD(...) |5| TAG(1) |6|
    try t.expectEqual(5, BackCul.payloadIndex(6));

    // |0| TAG(1) |1| PAYLOAD(4) |5| TAG(1) |6|
    try t.expectEqual(1, BothCul.payloadIndexDir(.forward, 0));
    try t.expectEqual(5, BothCul.payloadIndexDir(.backward, 6));
}

test "ForeCul.getBytes{Slice&Array}" {
    var forw = try ForCul.initBytesCapacity(ta, 69);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    try t.expectEqual(forw.bytes.items[6..][0..9], forw.getBytesSlice(6, 9));
    try t.expectEqual(forw.bytes.items[6..][0..9], forw.getBytesArray(6, 9));
}

test "BackCul.getBytes{Slice&Array}" {
    var back = try BackCul.initBytesCapacity(ta, 42);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    try t.expectEqual(back.bytes.items[4 - 2 ..][0..2], back.getBytesSlice(4, 2));
    try t.expectEqual(back.bytes.items[4 - 2 ..][0..2], back.getBytesArray(4, 2));
}

test "BothCul.getBytes{Slice&Array}Dir" {
    var both = try BothCul.initBytesCapacity(ta, 69 + 42);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    try t.expectEqual(both.bytes.items[6..][0..9], both.getBytesSliceDir(.forward, 6, 9));
    try t.expectEqual(both.bytes.items[6..][0..9], both.getBytesArrayDir(.forward, 6, 9));
    try t.expectEqual(
        both.bytes.items[4 - 2 ..][0..2],
        both.getBytesSliceDir(.backward, 4, 2),
    );
    try t.expectEqual(
        both.bytes.items[4 - 2 ..][0..2],
        both.getBytesArrayDir(.backward, 4, 2),
    );
}

test "ForeCul.getTypeBytes" {
    var forw = try ForCul.initBytesCapacity(ta, 16);
    defer forw.deinit(ta);

    forw.bytes.appendSliceAssumeCapacity(&.{
        2,  3,  5,  7,
        11, 13, 17, 19,
        23, 29, 31, 37,
        41, 43, 47, 53,
    });

    try t.expectEqualSlices(UByte, &[_]UByte{ 2, 3, 5, 7 }, forw.getTypeBytes(0, [4]UByte));
    try t.expectEqualSlices(UByte, &[_]UByte{ 37, 41, 43 }, forw.getTypeBytes(11, [3]UByte));
}

test "BackCul.getTypeBytes" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.appendSliceAssumeCapacity(&.{
        0, 1, 1, 2,
        3, 5, 8, 13,
    });

    try t.expectEqualSlices(UByte, &[_]UByte{ 1, 2, 3 }, back.getTypeBytes(5, [3]UByte));
    try t.expectEqualSlices(UByte, &[_]UByte{ 8, 13 }, back.getTypeBytes(8, [2]UByte));
}

test "BothCul.getTypeBytesDir" {
    var both = try BothCul.initBytesCapacity(ta, 12);
    defer both.deinit(ta);

    both.bytes.appendSliceAssumeCapacity(&.{
        0,  1,  4,   9,
        16, 25, 36,  49,
        64, 81, 100, 121,
    });

    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 0, 1, 4, 9 },
        both.getTypeBytesDir(.forward, 0, [4]UByte),
    );
    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 0, 1, 4, 9 },
        both.getTypeBytesDir(.backward, 4, [4]UByte),
    );

    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 36, 49, 64 },
        both.getTypeBytesDir(.forward, 6, [3]UByte),
    );
    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 36, 49, 64 },
        both.getTypeBytesDir(.backward, 9, [3]UByte),
    );
}

test "ForeCul.getType" {
    var forw = try ForCul.initBytesCapacity(ta, 8);
    defer forw.deinit(ta);

    try forw.bytes.fixedWriter().writeInt(u32, 3_141_592_653, endian);
    try forw.bytes.fixedWriter().writeInt(u32, 2_718_281_828, endian);

    try t.expectEqual(3_141_592_653, forw.getType(0, u32));
    try t.expectEqual(2_718_281_828, forw.getType(4, u32));
}

test "BackCul.getType" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    try back.bytes.fixedWriter().writeInt(u32, 1_618_033_988, endian);
    try back.bytes.fixedWriter().writeInt(u32, 1_414_213_562, endian);

    try t.expectEqual(1_618_033_988, back.getType(4, u32));
    try t.expectEqual(1_414_213_562, back.getType(8, u32));
}

test "BothCul.getTypeDir" {
    var both = try BothCul.initBytesCapacity(ta, 8);
    defer both.deinit(ta);

    try both.bytes.fixedWriter().writeInt(u32, 1_324_717_957, endian);
    try both.bytes.fixedWriter().writeInt(u32, 1_176_322_283, endian);

    try t.expectEqual(1_324_717_957, both.getTypeDir(.forward, 0, u32));
    try t.expectEqual(1_176_322_283, both.getTypeDir(.forward, 4, u32));
    try t.expectEqual(1_324_717_957, both.getTypeDir(.backward, 4, u32));
    try t.expectEqual(1_176_322_283, both.getTypeDir(.backward, 8, u32));
}

test "ForeCul.setType" {
    var forw = try ForCul.initBytesCapacity(ta, 16);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    forw.setType(1, struct { bool, u32 }, .{ true, 69 });
    try t.expectEqual(.{ true, 69 }, forw.getType(1, struct { bool, u32 }));
}

test "BackCul.setType" {
    var back = try BackCul.initBytesCapacity(ta, 75);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setType(71, Union, .empty);
    try t.expectEqual(.empty, back.getType(71, Union));
}

test "BothCul.setTypeDir" {
    var both = try BothCul.initBytesCapacity(ta, 32);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    both.setTypeDir(.forward, 5, []const UByte, "Hello world!");
    try t.expectEqualStrings("Hello world!", both.getTypeDir(.forward, 5, []const UByte));

    both.setTypeDir(.backward, 12, [2:2]u7, .{ 69, 42 });
    try t.expectEqual([_:2]u7{ 69, 42 }, both.getTypeDir(.backward, 12, [2:2]u7));
}

test "ForeCul.getTag" {
    var forw = try ForCul.initBytesCapacity(ta, 8);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    forw.setType(0, ForCul.Tag, .empty);
    forw.setType(1, ForCul.Tag, .byte);
    forw.setType(2, ForCul.Tag, .signed_byte);
    forw.setType(3, ForCul.Tag, .float);
    forw.setType(4, ForCul.Tag, .big_int);
    forw.setType(5, ForCul.Tag, .array);

    try t.expectEqual(.empty, forw.getTag(0));
    try t.expectEqual(.byte, forw.getTag(1));
    try t.expectEqual(.signed_byte, forw.getTag(2));
    try t.expectEqual(.float, forw.getTag(3));
    try t.expectEqual(.big_int, forw.getTag(4));
    try t.expectEqual(.array, forw.getTag(5));
}

test "BackCul.getTag" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setType(1, BackCul.Tag, .empty);
    back.setType(2, BackCul.Tag, .byte);
    back.setType(3, BackCul.Tag, .signed_byte);
    back.setType(4, BackCul.Tag, .float);
    back.setType(5, BackCul.Tag, .big_int);
    back.setType(6, BackCul.Tag, .array);

    try t.expectEqual(.empty, back.getTag(1));
    try t.expectEqual(.byte, back.getTag(2));
    try t.expectEqual(.signed_byte, back.getTag(3));
    try t.expectEqual(.float, back.getTag(4));
    try t.expectEqual(.big_int, back.getTag(5));
    try t.expectEqual(.array, back.getTag(6));
}

test "BothCul.getTagDir" {
    var both = try BothCul.initBytesCapacity(ta, 8);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    both.setTypeDir(.forward, 0, BothCul.Tag, .empty);
    both.setTypeDir(.forward, 1, BothCul.Tag, .byte);
    both.setTypeDir(.forward, 2, BothCul.Tag, .signed_byte);
    both.setTypeDir(.backward, 4, BothCul.Tag, .float);
    both.setTypeDir(.backward, 5, BothCul.Tag, .big_int);
    both.setTypeDir(.backward, 6, BothCul.Tag, .array);

    try t.expectEqual(.empty, both.getTagDir(.forward, 0));
    try t.expectEqual(.byte, both.getTagDir(.forward, 1));
    try t.expectEqual(.signed_byte, both.getTagDir(.forward, 2));
    try t.expectEqual(.float, both.getTagDir(.forward, 3));
    try t.expectEqual(.big_int, both.getTagDir(.forward, 4));
    try t.expectEqual(.array, both.getTagDir(.forward, 5));

    try t.expectEqual(.empty, both.getTagDir(.backward, 1));
    try t.expectEqual(.byte, both.getTagDir(.backward, 2));
    try t.expectEqual(.signed_byte, both.getTagDir(.backward, 3));
    try t.expectEqual(.float, both.getTagDir(.backward, 4));
    try t.expectEqual(.big_int, both.getTagDir(.backward, 5));
    try t.expectEqual(.array, both.getTagDir(.backward, 6));
}

test "ForeCul.setTagUnchecked" {
    var forw = try ForCul.initBytesCapacity(ta, 16);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    forw.setTagUnchecked(0, .empty);
    forw.setTagUnchecked(1, .byte);
    forw.setTagUnchecked(2, .signed_byte);
    forw.setTagUnchecked(3, .float);
    forw.setTagUnchecked(4, .big_int);
    forw.setTagUnchecked(5, .array);

    try t.expectEqual(.empty, forw.getTag(0));
    try t.expectEqual(.byte, forw.getTag(1));
    try t.expectEqual(.signed_byte, forw.getTag(2));
    try t.expectEqual(.float, forw.getTag(3));
    try t.expectEqual(.big_int, forw.getTag(4));
    try t.expectEqual(.array, forw.getTag(5));
}

test "BackCul.setTagUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 16);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(1, .byte);
    back.setTagUnchecked(2, .signed_byte);
    back.setTagUnchecked(3, .float);
    back.setTagUnchecked(4, .big_int);
    back.setTagUnchecked(5, .array);
    back.setTagUnchecked(6, .empty);

    try t.expectEqual(.byte, back.getTag(1));
    try t.expectEqual(.signed_byte, back.getTag(2));
    try t.expectEqual(.float, back.getTag(3));
    try t.expectEqual(.big_int, back.getTag(4));
    try t.expectEqual(.array, back.getTag(5));
    try t.expectEqual(.empty, back.getTag(6));
}

test "BothCul.setTagUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1|
    both.setTagUncheckedDir(.forward, 0, .empty);
    try t.expectEqual(.empty, both.getTagDir(.forward, 0));
    try t.expectEqual(.empty, both.getTagDir(.backward, 1));

    // |1| TAG(1) |2| BYTE(1) |3| TAG(1) |4|
    both.setTagUncheckedDir(.forward, 1, .byte);
    try t.expectEqual(.byte, both.getTagDir(.forward, 1));
    try t.expectEqual(.byte, both.getTagDir(.backward, 4));

    // |1| TAG(1) |2| FLOAT(4) |6| TAG(1) |7|
    both.setTagUncheckedDir(.backward, 7, .float);
    try t.expectEqual(.float, both.getTagDir(.forward, 1));
    try t.expectEqual(.float, both.getTagDir(.backward, 7));

    // |2| TAG(1) |3| ARRAY(4) |7| TAG(1) |8|
    both.setTagUncheckedDir(.forward, 2, .array);
    try t.expectEqual(.array, both.getTagDir(.forward, 2));
    try t.expectEqual(.array, both.getTagDir(.backward, 8));
}

test "ForeCul.checkSize" {
    var forw = try ForCul.initBytesCapacity(ta, 16);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    forw.setTagUnchecked(0, .empty);
    try forw.checkSize(0, .empty);
    try t.expectError(ForCul.SizeError.CurrentPayloadTooSmall, forw.checkSize(0, .byte));

    forw.setTagUnchecked(4, .byte);
    try forw.checkSize(4, .signed_byte);
    try t.expectError(ForCul.SizeError.CurrentPayloadTooBig, forw.checkSize(4, .empty));
}

test "BackCul.checkSize" {
    var back = try BackCul.initBytesCapacity(ta, 16);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(1, .empty);
    try back.checkSize(1, .empty);
    try t.expectError(BackCul.SizeError.CurrentPayloadTooSmall, back.checkSize(1, .byte));

    back.setTagUnchecked(4, .float);
    try back.checkSize(4, .array);
    try t.expectError(BackCul.SizeError.CurrentPayloadTooBig, back.checkSize(4, .byte));
}

test "BothCul.checkSizeDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    both.setTagUncheckedDir(.forward, 0, .empty);
    try both.checkSizeDir(.backward, 1, .empty);
    try t.expectError(
        BothCul.SizeError.CurrentPayloadTooSmall,
        both.checkSizeDir(.forward, 0, .byte),
    );

    // |4| TAG(1) |5| FLOAT(4) |9| TAG(1) |10|
    both.setTagUncheckedDir(.forward, 4, .float);
    try both.checkSizeDir(.backward, 10, .array);
    try t.expectError(
        BothCul.SizeError.CurrentPayloadTooBig,
        both.checkSizeDir(.forward, 4, .byte),
    );
}

test "ForeCul.getPayloadUnchecked" {
    var forw = try ForCul.initBytesCapacity(ta, 4);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    // |0| TAG(1) |1| BYTE(1) |2|
    forw.bytes.items[1] = 69;

    try t.expectEqual(69, forw.getPayloadUnchecked(.byte, 1));
    try t.expectEqual(
        @as(SByte, @bitCast(@as(UByte, 69))),
        forw.getPayloadUnchecked(.signed_byte, 1),
    );
}

test "BackCul.getPayloadUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 16);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| FLOAT(4) |4| TAG(1) |5|
    back.bytes.items[0] = 0;
    back.bytes.items[1] = 0;
    back.bytes.items[2] = 0;
    back.bytes.items[3] = 0;

    try t.expectEqual(0, back.getPayloadUnchecked(.float, 4));
}

test "BothCul.getPayloadUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |5| TAG(1) |6| ARRAY(4) |10| TAG(1) |11|
    both.bytes.items[6] = 2;
    both.bytes.items[7] = 6;
    both.bytes.items[8] = 24;
    both.bytes.items[9] = 120;

    try t.expectEqual([_]u8{ 2, 6, 24, 120 }, both.getPayloadUncheckedDir(.array, .forward, 6));
    try t.expectEqual([_]u8{ 2, 6, 24, 120 }, both.getPayloadUncheckedDir(.array, .backward, 10));
}

test "ForeCul.setPayloadUnchecked" {
    var forw = try ForCul.initBytesCapacity(ta, 16);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| SBYTE(1) |7|
    forw.setPayloadUnchecked(.float, 1, 3.1415);
    forw.setPayloadUnchecked(.signed_byte, 6, 69);

    try t.expectEqual(3.1415, forw.getPayloadUnchecked(.float, 1));
    try t.expectEqual(69, forw.getPayloadUnchecked(.signed_byte, 6));
}

test "BackCul.setPayloadUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 38);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| ARRAY(4) |4| TAG(1) |5| BIG_INT(32) |37| TAG(1) |38|
    back.setPayloadUnchecked(.array, 4, .{ 2, 6, 24, 120 });
    back.setPayloadUnchecked(.big_int, 37, 123456789);

    try t.expectEqual(.{ 2, 6, 24, 120 }, back.getPayloadUnchecked(.array, 4));
    try t.expectEqual(123456789, back.getPayloadUnchecked(.big_int, 37));
}

test "BothCul.setPayloadUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6|
    both.setPayloadUncheckedDir(.float, .forward, 1, 1.618);

    try t.expectEqual(1.618, both.getPayloadUncheckedDir(.float, .forward, 1));
    try t.expectEqual(1.618, both.getPayloadUncheckedDir(.float, .backward, 5));

    // |0| TAG(1) |1| BYTE |2| TAG(1) |3|
    both.setPayloadUncheckedDir(.byte, .backward, 2, 69);

    try t.expectEqual(69, both.getPayloadUncheckedDir(.byte, .backward, 2));
    try t.expectEqual(69, both.getPayloadUncheckedDir(.byte, .forward, 1));
}

test "ForeCul.checkTag" {
    var forw = try ForCul.initBytesCapacity(ta, 8);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    forw.setTagUnchecked(0, .empty);
    forw.setTagUnchecked(1, .byte);
    forw.setTagUnchecked(2, .signed_byte);
    forw.setTagUnchecked(3, .float);
    forw.setTagUnchecked(4, .array);
    forw.setTagUnchecked(5, .big_int);

    try forw.checkTag(0, .empty);
    try forw.checkTag(1, .byte);
    try forw.checkTag(2, .signed_byte);
    try forw.checkTag(3, .float);
    try forw.checkTag(4, .array);
    try forw.checkTag(5, .big_int);

    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(5, .empty));
    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(0, .byte));
    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(1, .signed_byte));
    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(2, .float));
    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(3, .array));
    try t.expectError(ForCul.TagError.WrongTag, forw.checkTag(4, .big_int));
}

test "BackCul.checkTag" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(6, .empty);
    back.setTagUnchecked(1, .byte);
    back.setTagUnchecked(2, .signed_byte);
    back.setTagUnchecked(3, .float);
    back.setTagUnchecked(4, .array);
    back.setTagUnchecked(5, .big_int);

    try back.checkTag(6, .empty);
    try back.checkTag(1, .byte);
    try back.checkTag(2, .signed_byte);
    try back.checkTag(3, .float);
    try back.checkTag(4, .array);
    try back.checkTag(5, .big_int);

    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(5, .empty));
    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(6, .byte));
    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(1, .signed_byte));
    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(2, .float));
    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(3, .array));
    try t.expectError(ForCul.TagError.WrongTag, back.checkTag(4, .big_int));
}

test "BothCul.checkTagDir" {
    var both = try BothCul.initBytesCapacity(ta, 8);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1|
    both.setTagUncheckedDir(.forward, 0, .empty);
    try both.checkTagDir(.forward, 0, .empty);
    try both.checkTagDir(.backward, 1, .empty);

    both.setTagUncheckedDir(.backward, 1, .empty);
    try both.checkTagDir(.forward, 0, .empty);
    try both.checkTagDir(.backward, 1, .empty);

    // |0| TAG(1) |1| BYTE(1) |2| TAG(1) |3|
    both.setTagUncheckedDir(.forward, 0, .byte);
    try both.checkTagDir(.forward, 0, .byte);
    try both.checkTagDir(.backward, 3, .byte);

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6|
    both.setTagUncheckedDir(.backward, 6, .float);
    try both.checkTagDir(.forward, 0, .float);
    try both.checkTagDir(.backward, 6, .float);
}

test "ForeCul.setVariantUnchecked" {
    var forw = try ForCul.initBytesCapacity(ta, 32);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    // |0| TAG(1) |1| BYTE(1) |2|
    forw.setVariantUnchecked(0, .byte, 69);
    try t.expectEqual(69, forw.getPayloadUnchecked(.byte, ForCul.payloadIndex(0)));
    try t.expectEqual(.byte, forw.getTag(0));

    // |2| TAG(1) |3| FLOAT(4) |7|
    forw.setVariantUnchecked(2, .float, 3.1415);
    try t.expectEqual(3.1415, forw.getPayloadUnchecked(.float, ForCul.payloadIndex(2)));
    try t.expectEqual(.float, forw.getTag(2));
}

test "BackCul.setVariantUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| ARRAY(4) |4| TAG(1) |5|
    back.setVariantUnchecked(5, .array, .{ 4, 9, 16, 25 });
    try t.expectEqual(.array, back.getTag(5));
    try t.expectEqual(
        .{ 4, 9, 16, 25 },
        back.getPayloadUnchecked(.array, BackCul.payloadIndex(5)),
    );

    // |5| BYTE(1) |6| TAG(1) |7|
    back.setVariantUnchecked(7, .byte, 69);
    try t.expectEqual(.byte, back.getTag(7));
    try t.expectEqual(69, back.getPayloadUnchecked(.byte, BackCul.payloadIndex(7)));
}
test "BothCul.setVariantUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |4| TAG(1) |5| ARRAY(4) |9| TAG(1) |10|
    both.setVariantUncheckedDir(.forward, 4, .array, .{ 1, 8, 27, 64 });
    try t.expectEqual(.array, both.getTagDir(.forward, 4));
    try t.expectEqual(.array, both.getTagDir(.backward, 10));
    try t.expectEqual(.{ 1, 8, 27, 64 }, both.getPayloadUncheckedDir(
        .array,
        .forward,
        BothCul.payloadIndexDir(.forward, 4),
    ));
    try t.expectEqual(.{ 1, 8, 27, 64 }, both.getPayloadUncheckedDir(
        .array,
        .backward,
        BothCul.payloadIndexDir(.backward, 10),
    ));

    // |3| TAG(1) |4| BYTE(1) |5| TAG(1) |6|
    both.setVariantUncheckedDir(.backward, 6, .byte, 69);
    try t.expectEqual(.byte, both.getTagDir(.forward, 3));
    try t.expectEqual(.byte, both.getTagDir(.backward, 6));
    try t.expectEqual(69, both.getPayloadUncheckedDir(
        .byte,
        .forward,
        BothCul.payloadIndexDir(.forward, 3),
    ));
    try t.expectEqual(69, both.getPayloadUncheckedDir(
        .byte,
        .backward,
        BothCul.payloadIndexDir(.backward, 6),
    ));
}

test "ForeCul.get" {
    var forw = try ForCul.initBytesCapacity(ta, 10);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    // |0| TAG(1) |1| ARRAY(4) |5| TAG(1) |6| FLOAT(4) |10|
    forw.setVariantUnchecked(0, .array, .{ 0, 1, 16, 81 });
    forw.setVariantUnchecked(5, .float, 1.61);

    try t.expectEqual(Union{ .array = .{ 0, 1, 16, 81 } }, forw.get(0));
    try t.expectEqual(Union{ .float = 1.61 }, forw.get(5));
}
test "BackCul.get" {
    var back = try BackCul.initBytesCapacity(ta, 7);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| BYTE(1) |1| TAG(1) |2| ARRAY(4) |6| TAG(1) |7|
    back.setVariantUnchecked(2, .byte, 69);
    back.setVariantUnchecked(7, .array, .{ 1, 2, 3, 4 });

    try t.expectEqual(Union{ .byte = 69 }, back.get(2));
    try t.expectEqual(Union{ .array = .{ 1, 2, 3, 4 } }, back.get(7));
}
test "BothCul.getDir" {
    var both = try BothCul.initBytesCapacity(ta, 12);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| TAG(1) |7| ARRAY(4) |11| TAG(1) |12|
    both.setVariantUncheckedDir(.forward, 0, .float, 3.1415);
    both.setVariantUncheckedDir(.backward, 12, .array, .{ 15, 46, 23, 70 });

    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.forward, 0));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, 6));

    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.forward, 6));
    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.backward, 12));
}

test "ForeCul.setUnchecked" {
    var forw = try ForCul.initBytesCapacity(ta, 10);
    defer forw.deinit(ta);

    forw.bytes.expandToCapacity();

    // |0| TAG(1) |1| ARRAY(4) |5| TAG(1) |6| FLOAT(4) |10|
    forw.setUnchecked(0, Union{ .array = .{ 0, 1, 16, 81 } });
    forw.setUnchecked(5, Union{ .float = 1.61 });

    try t.expectEqual(Union{ .array = .{ 0, 1, 16, 81 } }, forw.get(0));
    try t.expectEqual(Union{ .float = 1.61 }, forw.get(5));
}
test "BackCul.setUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 7);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| BYTE(1) |1| TAG(1) |2| ARRAY(4) |6| TAG(1) |7|
    back.setUnchecked(2, Union{ .byte = 69 });
    back.setUnchecked(7, Union{ .array = .{ 1, 2, 3, 4 } });

    try t.expectEqual(Union{ .byte = 69 }, back.get(2));
    try t.expectEqual(Union{ .array = .{ 1, 2, 3, 4 } }, back.get(7));
}
test "BothCul.setUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 12);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| TAG(1) |7| ARRAY(4) |11| TAG(1) |12|
    both.setUncheckedDir(.forward, 0, Union{ .float = 3.1415 });
    both.setUncheckedDir(.backward, 12, Union{ .array = .{ 15, 46, 23, 70 } });

    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.forward, 0));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, 6));

    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.forward, 6));
    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.backward, 12));
}

test "ForeCul.append" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    const first_index = forw.bytes.items.len;
    try forw.append(ta, .empty);

    const second_index = forw.bytes.items.len;
    try forw.append(ta, .{ .byte = 69 });

    const third_index = forw.bytes.items.len;
    try forw.append(ta, .{ .float = 3.1415 });

    try t.expectEqual(Union.empty, forw.get(first_index));
    try t.expectEqual(Union{ .byte = 69 }, forw.get(second_index));
    try t.expectEqual(Union{ .float = 3.1415 }, forw.get(third_index));
}
test "BackCul.append" {
    var back = BackCul{};
    defer back.deinit(ta);

    try back.append(ta, .empty);
    const first_index = back.bytes.items.len;

    try back.append(ta, .{ .byte = 69 });
    const second_index = back.bytes.items.len;

    try back.append(ta, .{ .float = 3.1415 });
    const third_index = back.bytes.items.len;

    try t.expectEqual(Union.empty, back.get(first_index));
    try t.expectEqual(Union{ .byte = 69 }, back.get(second_index));
    try t.expectEqual(Union{ .float = 3.1415 }, back.get(third_index));
}
test "BothCul.append" {
    var both = BothCul{};
    defer both.deinit(ta);

    const first_forw_index = both.bytes.items.len;
    try both.append(ta, .empty);
    const first_back_index = both.bytes.items.len;

    const second_forw_index = both.bytes.items.len;
    try both.append(ta, .{ .byte = 69 });
    const second_back_index = both.bytes.items.len;

    const third_forw_index = both.bytes.items.len;
    try both.append(ta, .{ .float = 3.1415 });
    const third_back_index = both.bytes.items.len;

    try t.expectEqual(Union.empty, both.getDir(.forward, first_forw_index));
    try t.expectEqual(Union{ .byte = 69 }, both.getDir(.forward, second_forw_index));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.forward, third_forw_index));

    try t.expectEqual(Union.empty, both.getDir(.backward, first_back_index));
    try t.expectEqual(Union{ .byte = 69 }, both.getDir(.backward, second_back_index));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, third_back_index));
}

test "ForeCul.iterate" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    try forw.append(ta, .empty);
    try forw.append(ta, .{ .byte = 69 });
    try forw.append(ta, .{ .signed_byte = -1 });
    try forw.append(ta, .{ .float = 3.1415 });
    try forw.append(ta, .{ .array = .{ 1, 2, 4, 8 } });

    var iter = forw.iterate();

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = -1 }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 1, 2, 4, 8 } }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BackCul.iterate" {
    var back = BackCul{};
    defer back.deinit(ta);

    try back.append(ta, .empty);
    try back.append(ta, .{ .byte = 69 });
    try back.append(ta, .{ .signed_byte = -1 });
    try back.append(ta, .{ .float = 3.1415 });
    try back.append(ta, .{ .array = .{ 1, 2, 4, 8 } });

    var iter = back.iterate();

    try t.expectEqual(Union{ .array = .{ 1, 2, 4, 8 } }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = -1 }, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BothCul.iterate" {
    var both = BothCul{};
    defer both.deinit(ta);

    try both.append(ta, .empty);
    try both.append(ta, .{ .byte = 69 });
    try both.append(ta, .{ .signed_byte = -1 });
    try both.append(ta, .{ .float = 3.1415 });
    try both.append(ta, .{ .array = .{ 1, 2, 4, 8 } });

    var iter = both.iterateDir(.forward);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = -1 }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 1, 2, 4, 8 } }, iter.next());
    try t.expectEqual(null, iter.next());
    try t.expectEqual(null, iter.next());

    var riter = iter.reverse();

    try t.expectEqual(Union{ .array = .{ 1, 2, 4, 8 } }, riter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, riter.next());
    try t.expectEqual(Union{ .signed_byte = -1 }, riter.next());
    try t.expectEqual(Union{ .byte = 69 }, riter.next());
    try t.expectEqual(Union.empty, riter.next());
}

test "ForeCul.resolveIndex" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    try t.expectEqual(null, forw.resolveIndex(0));

    try forw.append(ta, .empty);
    try t.expectEqual(0, forw.resolveIndex(0));

    try forw.append(ta, .{ .big_int = 1000_000_000_000_000_000_000 });
    try t.expectEqual(1, forw.resolveIndex(1));

    try forw.append(ta, .{ .float = 24.60 });
    try t.expectEqual(34, forw.resolveIndex(2));
    try t.expectEqual(Union{ .float = 24.60 }, forw.get(34));

    try t.expectEqual(null, forw.resolveIndex(3));
}

test "BackCul.resolveIndex" {
    var back = BackCul{};
    defer back.deinit(ta);

    try t.expectEqual(null, back.resolveIndex(0));

    try back.append(ta, .empty);
    try t.expectEqual(1, back.resolveIndex(0));

    try back.append(ta, .{ .big_int = 1000_000_000_000_000_000_000 });
    try t.expectEqual(34, back.resolveIndex(0));

    try back.append(ta, .{ .float = 24.60 });
    try t.expectEqual(39, back.resolveIndex(0));
    try t.expectEqual(Union{ .float = 24.60 }, back.get(39));

    try t.expectEqual(null, back.resolveIndex(3));
}

test "BothCul.resolveIndex" {
    var both = BothCul{};
    defer both.deinit(ta);

    try t.expectEqual(null, both.resolveIndexDir(.forward, 0));
    try t.expectEqual(null, both.resolveIndexDir(.backward, 0));

    try both.append(ta, .empty);
    try t.expectEqual(0, both.resolveIndexDir(.forward, 0));
    try t.expectEqual(1, both.resolveIndexDir(.backward, 0));

    try both.append(ta, .{ .big_int = 31415 });
    try t.expectEqual(1, both.resolveIndexDir(.forward, 1));
    try t.expectEqual(Union{ .big_int = 31415 }, both.getDir(.forward, 1));
    try t.expectEqual(35, both.resolveIndexDir(.backward, 0));
    try t.expectEqual(Union{ .big_int = 31415 }, both.getDir(.backward, 35));
}

test "ForeCul.insertVariant" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    try forw.insertVariant(ta, 0, .empty, {});
    try t.expectEqual(Union.empty, forw.get(0));

    try forw.insertVariant(ta, 1, .byte, 69);
    var iter = forw.iterate();

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    try forw.insertVariant(ta, iter.idx, .array, .{ 0, 1, 32, 243 });
    iter = .init(&forw);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 0, 1, 32, 243 } }, iter.next());
    try t.expectEqual(null, iter.next());

    const idx = forw.resolveIndex(2) orelse return error.UnexpectedNull;
    try forw.insertVariant(ta, idx, .float, 3.1415);
    iter = .init(&forw);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 0, 1, 32, 243 } }, iter.next());
    try t.expectEqual(null, iter.next());

    try forw.insertVariant(ta, 0, .big_int, 35148_3773);
    iter = .init(&forw);

    try t.expectEqual(Union{ .big_int = 35148_3773 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 0, 1, 32, 243 } }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BackCul.insertVariant" {
    var back = BackCul{};
    defer back.deinit(ta);

    try back.insertVariant(ta, 1, .empty, {});
    try t.expectEqual(Union.empty, back.get(1));

    try back.insertVariant(ta, 2, .byte, 69);
    var iter = back.iterate();

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    try back.insertVariant(ta, 5, .float, 1.618);
    iter = .init(&back);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(null, iter.next());

    try back.insertVariant(ta, back.bytes.items.len + 5, .array, .{ 2, 3, 5, 7 });
    iter = .init(&back);

    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BothCul.insertVariant" {
    var both = BothCul{};
    defer both.deinit(ta);

    try both.insertVariantDir(ta, .forward, 0, .empty, {});
    try t.expectEqual(Union.empty, both.getDir(.forward, 0));

    try both.insertVariantDir(ta, .backward, 6, .float, 1.618);
    try t.expectEqual(Union{ .float = 1.618 }, both.getDir(.forward, 0));

    try both.insertVariantDir(ta, .backward, both.bytes.items.len + 3, .byte, 69);

    var iter = both.iterateDir(.forward);

    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "ForeCul.remove" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    try forw.append(ta, .empty);
    forw.remove(0);

    var iter = forw.iterate();
    try t.expectEqual(null, iter.next());

    try forw.append(ta, .{ .byte = 69 });
    try forw.append(ta, .{ .float = 1.618 });
    try forw.append(ta, .{ .signed_byte = 42 });

    iter = forw.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(null, iter.next());

    var index = forw.resolveIndex(1) orelse return error.UnexpectedNull;
    forw.remove(index);

    iter = forw.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = forw.resolveIndex(1) orelse return error.UnexpectedNull;
    forw.remove(index);

    iter = forw.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    forw.remove(0);
    iter = forw.iterate();
    try t.expectEqual(null, iter.next());
}

test "BackCul.remove" {
    var back = BackCul{};
    defer back.deinit(ta);

    try back.append(ta, .empty);
    var index = back.resolveIndex(0) orelse return error.UnexpectedNull;

    back.remove(index);

    var iter = back.iterate();
    try t.expectEqual(null, iter.next());

    try back.append(ta, .{ .byte = 69 });
    try back.append(ta, .{ .float = 1.618 });
    try back.append(ta, .{ .signed_byte = 42 });

    iter = back.iterate();
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = back.resolveIndex(1) orelse return error.UnexpectedNull;
    back.remove(index);

    iter = back.iterate();
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = back.resolveIndex(1) orelse return error.UnexpectedNull;
    back.remove(index);

    iter = back.iterate();
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = back.resolveIndex(0) orelse return error.UnexpectedNull;
    back.remove(index);

    iter = back.iterate();
    try t.expectEqual(null, iter.next());
}

test "BothCul.remove" {
    var both = BothCul{};
    defer both.deinit(ta);

    try both.append(ta, Union{ .float = 3.1415 });
    try both.append(ta, Union{ .byte = 69 });
    try both.append(ta, Union{ .array = .{ 23, 29, 31, 37 } });
    try both.append(ta, Union.empty);

    var forw_iter = both.iterateDir(.forward);

    try t.expectEqual(Union{ .float = 3.1415 }, forw_iter.next());
    try t.expectEqual(Union{ .byte = 69 }, forw_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, forw_iter.next());
    try t.expectEqual(Union.empty, forw_iter.next());
    try t.expectEqual(null, forw_iter.next());

    var back_iter = forw_iter.reverse();

    try t.expectEqual(Union.empty, back_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, back_iter.next());
    try t.expectEqual(Union{ .byte = 69 }, back_iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, back_iter.next());
    try t.expectEqual(null, back_iter.next());

    var index = both.resolveIndexDir(.forward, 1) orelse return error.UnexpectedNull;
    both.removeDir(.forward, index);
    forw_iter = .init(&both);

    try t.expectEqual(Union{ .float = 3.1415 }, forw_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, forw_iter.next());
    try t.expectEqual(Union.empty, forw_iter.next());
    try t.expectEqual(null, forw_iter.next());

    index = both.resolveIndexDir(.backward, 0) orelse return error.UnexpectedNull;
    both.removeDir(.backward, index);
    back_iter = .init(&both);

    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, back_iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, back_iter.next());
    try t.expectEqual(null, back_iter.next());
}

test "ForCul.setVariantResizeVariantUnchecked" {
    var forw = ForCul{};
    defer forw.deinit(ta);

    try forw.append(ta, .{ .array = .{ 2, 3, 5, 7 } });
    try forw.append(ta, .empty);
    try forw.append(ta, .{ .float = 3.14 });

    try forw.setVariantResizeVariantUnchecked(ta, 5, .empty, .byte, 69);

    var iter = forw.iterate();

    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 3.14 }, iter.next());
    try t.expectEqual(null, iter.next());

    const index = forw.resolveIndex(2) orelse return error.UnexpectedNull;
    try forw.setVariantResizeVariantUnchecked(ta, index, .float, .signed_byte, -42);

    iter = forw.iterate();

    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = -42 }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BackCul.setVariantResizeVariantUnchecked" {
    var back = BackCul{};
    defer back.deinit(ta);

    try back.append(ta, .{ .array = .{ 2, 3, 5, 7 } });
    try back.append(ta, .empty);
    try back.append(ta, .{ .float = 3.1415 });

    var iter = back.iterate();

    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, iter.next());
    try t.expectEqual(null, iter.next());

    var index = back.resolveIndex(2) orelse return error.UnexpectedNull;
    try back.setVariantResizeVariantUnchecked(ta, index, .array, .byte, 69);

    iter = back.iterate();

    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = back.resolveIndex(2) orelse return error.UnexpectedNull;
    try back.setVariantResizeVariantUnchecked(ta, index, .byte, .signed_byte, -42);

    iter = back.iterate();

    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .signed_byte = -42 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = back.resolveIndex(1) orelse return error.UnexpectedNull;
    try back.setVariantResizeVariantUnchecked(ta, index, .empty, .array, .{ 2, 3, 5, 8 });

    iter = back.iterate();

    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 8 } }, iter.next());
    try t.expectEqual(Union{ .signed_byte = -42 }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "BothCul.setVariantResizeVariantUncheckedDir" {
    var both = BothCul{};
    defer both.deinit(ta);

    try both.append(ta, .{ .array = .{ 2, 3, 5, 7 } });
    try both.append(ta, .empty);
    try both.append(ta, .{ .big_int = 10_000_000_000 });

    var forw_iter = both.iterateDir(.forward);

    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, forw_iter.next());
    try t.expectEqual(Union.empty, forw_iter.next());
    try t.expectEqual(Union{ .big_int = 10_000_000_000 }, forw_iter.next());
    try t.expectEqual(null, forw_iter.next());

    var back_iter = both.iterateDir(.backward);

    try t.expectEqual(Union{ .big_int = 10_000_000_000 }, back_iter.next());
    try t.expectEqual(Union.empty, back_iter.next());
    try t.expectEqual(Union{ .array = .{ 2, 3, 5, 7 } }, back_iter.next());
    try t.expectEqual(null, back_iter.next());

    forw_iter = .init(&both);
    try both.setVariantResizeVariantUncheckedDir(ta, .forward, 0, .array, .byte, 69);

    try t.expectEqual(Union{ .byte = 69 }, forw_iter.next());
    try t.expectEqual(Union.empty, forw_iter.next());
    try t.expectEqual(Union{ .big_int = 10_000_000_000 }, forw_iter.next());
    try t.expectEqual(null, forw_iter.next());

    try both.setVariantResizeVariantUncheckedDir(ta, .backward, both.bytes.items.len, .big_int, .float, 3.14);
    back_iter = .init(&both);

    try t.expectEqual(Union{ .float = 3.14 }, back_iter.next());
    try t.expectEqual(Union.empty, back_iter.next());
    try t.expectEqual(Union{ .byte = 69 }, back_iter.next());
    try t.expectEqual(null, back_iter.next());
}
