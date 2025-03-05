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
const ForeCul = CompactUnionList(Union, .{ .iteration = .foreward });
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
    var cul = try ForeCul.initBytesCapacity(ta, 12);
    cul.deinit(ta);
}

test "Cul.payloadSize" {
    try t.expectEqual(0, ForeCul.payloadSize(.empty));
    try t.expectEqual(1, ForeCul.payloadSize(.byte));
    try t.expectEqual(1, ForeCul.payloadSize(.signed_byte));
    try t.expectEqual(4, ForeCul.payloadSize(.float));
    try t.expectEqual(32, ForeCul.payloadSize(.big_int));
    try t.expectEqual(4, ForeCul.payloadSize(.array));

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
    try t.expectEqual(1 + 0, ForeCul.variantSize(.empty));
    try t.expectEqual(1 + 1, ForeCul.variantSize(.byte));
    try t.expectEqual(1 + 1, ForeCul.variantSize(.signed_byte));
    try t.expectEqual(1 + 4, ForeCul.variantSize(.float));
    try t.expectEqual(1 + 32, ForeCul.variantSize(.big_int));
    try t.expectEqual(1 + 4, ForeCul.variantSize(.array));

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
    try t.expectEqual(0, ForeCul.tagIndex(1));

    // |...| PAYLOAD(...) |5| TAG(1) |6|
    try t.expectEqual(6, BackCul.tagIndex(5));

    // |0| TAG(1) |1| PAYLOAD(4) |5| TAG(1) |6|
    try t.expectEqual(0, BothCul.tagIndexDir(.foreward, 1));
    try t.expectEqual(6, BothCul.tagIndexDir(.backward, 5));
}

test "Cul.payloadIndex" {
    // |0| TAG(1) |1| PAYLOAD(...) |...|
    try t.expectEqual(1, ForeCul.payloadIndex(0));

    // |...| PAYLOAD(...) |5| TAG(1) |6|
    try t.expectEqual(5, BackCul.payloadIndex(6));

    // |0| TAG(1) |1| PAYLOAD(4) |5| TAG(1) |6|
    try t.expectEqual(1, BothCul.payloadIndexDir(.foreward, 0));
    try t.expectEqual(5, BothCul.payloadIndexDir(.backward, 6));
}

test "ForeCul.getBytes{Slice&Array}" {
    var fore = try ForeCul.initBytesCapacity(ta, 69);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    try t.expectEqual(fore.bytes.items[6..][0..9], fore.getBytesSlice(6, 9));
    try t.expectEqual(fore.bytes.items[6..][0..9], fore.getBytesArray(6, 9));
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

    try t.expectEqual(both.bytes.items[6..][0..9], both.getBytesSliceDir(.foreward, 6, 9));
    try t.expectEqual(both.bytes.items[6..][0..9], both.getBytesArrayDir(.foreward, 6, 9));
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
    var fore = try ForeCul.initBytesCapacity(ta, 16);
    defer fore.deinit(ta);

    fore.bytes.appendSliceAssumeCapacity(&.{
        2,  3,  5,  7,
        11, 13, 17, 19,
        23, 29, 31, 37,
        41, 43, 47, 53,
    });

    try t.expectEqualSlices(UByte, &[_]UByte{ 2, 3, 5, 7 }, fore.getTypeBytes([4]UByte, 0));
    try t.expectEqualSlices(UByte, &[_]UByte{ 37, 41, 43 }, fore.getTypeBytes([3]UByte, 11));
}
test "BackCul.getTypeBytes" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.appendSliceAssumeCapacity(&.{
        0, 1, 1, 2,
        3, 5, 8, 13,
    });

    try t.expectEqualSlices(UByte, &[_]UByte{ 1, 2, 3 }, back.getTypeBytes([3]UByte, 5));
    try t.expectEqualSlices(UByte, &[_]UByte{ 8, 13 }, back.getTypeBytes([2]UByte, 8));
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
        both.getTypeBytesDir(.foreward, [4]UByte, 0),
    );
    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 0, 1, 4, 9 },
        both.getTypeBytesDir(.backward, [4]UByte, 4),
    );

    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 36, 49, 64 },
        both.getTypeBytesDir(.foreward, [3]UByte, 6),
    );
    try t.expectEqualSlices(
        UByte,
        &[_]UByte{ 36, 49, 64 },
        both.getTypeBytesDir(.backward, [3]UByte, 9),
    );
}

test "ForeCul.getType" {
    var fore = try ForeCul.initBytesCapacity(ta, 8);
    defer fore.deinit(ta);

    try fore.bytes.fixedWriter().writeInt(u32, 3_141_592_653, endian);
    try fore.bytes.fixedWriter().writeInt(u32, 2_718_281_828, endian);

    try t.expectEqual(3_141_592_653, fore.getType(u32, 0));
    try t.expectEqual(2_718_281_828, fore.getType(u32, 4));
}
test "BackCul.getType" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    try back.bytes.fixedWriter().writeInt(u32, 1_618_033_988, endian);
    try back.bytes.fixedWriter().writeInt(u32, 1_414_213_562, endian);

    try t.expectEqual(1_618_033_988, back.getType(u32, 4));
    try t.expectEqual(1_414_213_562, back.getType(u32, 8));
}
test "BothCul.getTypeDir" {
    var both = try BothCul.initBytesCapacity(ta, 8);
    defer both.deinit(ta);

    try both.bytes.fixedWriter().writeInt(u32, 1_324_717_957, endian);
    try both.bytes.fixedWriter().writeInt(u32, 1_176_322_283, endian);

    try t.expectEqual(1_324_717_957, both.getTypeDir(.foreward, u32, 0));
    try t.expectEqual(1_176_322_283, both.getTypeDir(.foreward, u32, 4));
    try t.expectEqual(1_324_717_957, both.getTypeDir(.backward, u32, 4));
    try t.expectEqual(1_176_322_283, both.getTypeDir(.backward, u32, 8));
}

test "ForeCul.setType" {
    var fore = try ForeCul.initBytesCapacity(ta, 16);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    fore.setType(struct { bool, u32 }, .{ true, 69 }, 1);
    try t.expectEqual(.{ true, 69 }, fore.getType(struct { bool, u32 }, 1));
}
test "BackCul.setType" {
    var back = try BackCul.initBytesCapacity(ta, 75);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setType(Union, .empty, 71);
    try t.expectEqual(.empty, back.getType(Union, 71));
}
test "BothCul.setTypeDir" {
    var both = try BothCul.initBytesCapacity(ta, 32);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    both.setTypeDir(.foreward, []const UByte, "Hello world!", 5);
    try t.expectEqualStrings("Hello world!", both.getTypeDir(.foreward, []const UByte, 5));

    both.setTypeDir(.backward, [2:2]u7, .{ 69, 42 }, 12);
    try t.expectEqual([_:2]u7{ 69, 42 }, both.getTypeDir(.backward, [2:2]u7, 12));
}

test "ForeCul.getTag" {
    var fore = try ForeCul.initBytesCapacity(ta, 8);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    fore.setType(ForeCul.Tag, .empty, 0);
    fore.setType(ForeCul.Tag, .byte, 1);
    fore.setType(ForeCul.Tag, .signed_byte, 2);
    fore.setType(ForeCul.Tag, .float, 3);
    fore.setType(ForeCul.Tag, .big_int, 4);
    fore.setType(ForeCul.Tag, .array, 5);

    try t.expectEqual(.empty, fore.getTag(0));
    try t.expectEqual(.byte, fore.getTag(1));
    try t.expectEqual(.signed_byte, fore.getTag(2));
    try t.expectEqual(.float, fore.getTag(3));
    try t.expectEqual(.big_int, fore.getTag(4));
    try t.expectEqual(.array, fore.getTag(5));
}
test "BackCul.getTag" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setType(BackCul.Tag, .empty, 1);
    back.setType(BackCul.Tag, .byte, 2);
    back.setType(BackCul.Tag, .signed_byte, 3);
    back.setType(BackCul.Tag, .float, 4);
    back.setType(BackCul.Tag, .big_int, 5);
    back.setType(BackCul.Tag, .array, 6);

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

    both.setTypeDir(.foreward, BothCul.Tag, .empty, 0);
    both.setTypeDir(.foreward, BothCul.Tag, .byte, 1);
    both.setTypeDir(.foreward, BothCul.Tag, .signed_byte, 2);
    both.setTypeDir(.backward, BothCul.Tag, .float, 4);
    both.setTypeDir(.backward, BothCul.Tag, .big_int, 5);
    both.setTypeDir(.backward, BothCul.Tag, .array, 6);

    try t.expectEqual(.empty, both.getTagDir(.foreward, 0));
    try t.expectEqual(.byte, both.getTagDir(.foreward, 1));
    try t.expectEqual(.signed_byte, both.getTagDir(.foreward, 2));
    try t.expectEqual(.float, both.getTagDir(.foreward, 3));
    try t.expectEqual(.big_int, both.getTagDir(.foreward, 4));
    try t.expectEqual(.array, both.getTagDir(.foreward, 5));

    try t.expectEqual(.empty, both.getTagDir(.backward, 1));
    try t.expectEqual(.byte, both.getTagDir(.backward, 2));
    try t.expectEqual(.signed_byte, both.getTagDir(.backward, 3));
    try t.expectEqual(.float, both.getTagDir(.backward, 4));
    try t.expectEqual(.big_int, both.getTagDir(.backward, 5));
    try t.expectEqual(.array, both.getTagDir(.backward, 6));
}

test "ForeCul.setTagUnchecked" {
    var fore = try ForeCul.initBytesCapacity(ta, 16);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    fore.setTagUnchecked(.empty, 0);
    fore.setTagUnchecked(.byte, 1);
    fore.setTagUnchecked(.signed_byte, 2);
    fore.setTagUnchecked(.float, 3);
    fore.setTagUnchecked(.big_int, 4);
    fore.setTagUnchecked(.array, 5);

    try t.expectEqual(.empty, fore.getTag(0));
    try t.expectEqual(.byte, fore.getTag(1));
    try t.expectEqual(.signed_byte, fore.getTag(2));
    try t.expectEqual(.float, fore.getTag(3));
    try t.expectEqual(.big_int, fore.getTag(4));
    try t.expectEqual(.array, fore.getTag(5));
}
test "BackCul.setTagUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 16);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(.byte, 1);
    back.setTagUnchecked(.signed_byte, 2);
    back.setTagUnchecked(.float, 3);
    back.setTagUnchecked(.big_int, 4);
    back.setTagUnchecked(.array, 5);
    back.setTagUnchecked(.empty, 6);

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
    both.setTagUncheckedDir(.foreward, .empty, 0);
    try t.expectEqual(.empty, both.getTagDir(.foreward, 0));
    try t.expectEqual(.empty, both.getTagDir(.backward, 1));

    // |1| TAG(1) |2| BYTE(1) |3| TAG(1) |4|
    both.setTagUncheckedDir(.foreward, .byte, 1);
    try t.expectEqual(.byte, both.getTagDir(.foreward, 1));
    try t.expectEqual(.byte, both.getTagDir(.backward, 4));

    // |1| TAG(1) |2| FLOAT(4) |6| TAG(1) |7|
    both.setTagUncheckedDir(.backward, .float, 7);
    try t.expectEqual(.float, both.getTagDir(.foreward, 1));
    try t.expectEqual(.float, both.getTagDir(.backward, 7));

    // |2| TAG(1) |3| ARRAY(4) |7| TAG(1) |8|
    both.setTagUncheckedDir(.foreward, .array, 2);
    try t.expectEqual(.array, both.getTagDir(.foreward, 2));
    try t.expectEqual(.array, both.getTagDir(.backward, 8));
}

test "ForeCul.checkSize" {
    var fore = try ForeCul.initBytesCapacity(ta, 16);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    fore.setTagUnchecked(.empty, 0);
    try fore.checkSize(.empty, 0);
    try t.expectError(ForeCul.SizeError.CurrentPayloadTooSmall, fore.checkSize(.byte, 0));

    fore.setTagUnchecked(.byte, 4);
    try fore.checkSize(.signed_byte, 4);
    try t.expectError(ForeCul.SizeError.CurrentPayloadTooBig, fore.checkSize(.empty, 4));
}
test "BackCul.checkSize" {
    var back = try BackCul.initBytesCapacity(ta, 16);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(.empty, 1);
    try back.checkSize(.empty, 1);
    try t.expectError(BackCul.SizeError.CurrentPayloadTooSmall, back.checkSize(.byte, 1));

    back.setTagUnchecked(.float, 4);
    try back.checkSize(.array, 4);
    try t.expectError(BackCul.SizeError.CurrentPayloadTooBig, back.checkSize(.byte, 4));
}
test "BothCul.checkSizeDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    both.setTagUncheckedDir(.foreward, .empty, 0);
    try both.checkSizeDir(.backward, .empty, 1);
    try t.expectError(
        BothCul.SizeError.CurrentPayloadTooSmall,
        both.checkSizeDir(.foreward, .byte, 0),
    );

    // |4| TAG(1) |5| FLOAT(4) |9| TAG(1) |10|
    both.setTagUncheckedDir(.foreward, .float, 4);
    try both.checkSizeDir(.backward, .array, 10);
    try t.expectError(
        BothCul.SizeError.CurrentPayloadTooBig,
        both.checkSizeDir(.foreward, .byte, 4),
    );
}

test "ForeCul.getPayloadUnchecked" {
    var fore = try ForeCul.initBytesCapacity(ta, 4);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    // |0| TAG(1) |1| BYTE(1) |2|
    fore.bytes.items[1] = 69;

    try t.expectEqual(69, fore.getPayloadUnchecked(.byte, 1));
    try t.expectEqual(
        @as(SByte, @bitCast(@as(UByte, 69))),
        fore.getPayloadUnchecked(.signed_byte, 1),
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

    try t.expectEqual([_]u8{ 2, 6, 24, 120 }, both.getPayloadUncheckedDir(.foreward, .array, 6));
    try t.expectEqual([_]u8{ 2, 6, 24, 120 }, both.getPayloadUncheckedDir(.backward, .array, 10));
}

test "ForeCul.setPayloadUnchecked" {
    var fore = try ForeCul.initBytesCapacity(ta, 16);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| SBYTE(1) |7|
    fore.setPayloadUnchecked(.float, 3.1415, 1);
    fore.setPayloadUnchecked(.signed_byte, 69, 6);

    try t.expectEqual(3.1415, fore.getPayloadUnchecked(.float, 1));
    try t.expectEqual(69, fore.getPayloadUnchecked(.signed_byte, 6));
}
test "BackCul.setPayloadUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 38);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| ARRAY(4) |4| TAG(1) |5| BIG_INT(32) |37| TAG(1) |38|
    back.setPayloadUnchecked(.array, .{ 2, 6, 24, 120 }, 4);
    back.setPayloadUnchecked(.big_int, 123456789, 37);

    try t.expectEqual(.{ 2, 6, 24, 120 }, back.getPayloadUnchecked(.array, 4));
    try t.expectEqual(123456789, back.getPayloadUnchecked(.big_int, 37));
}
test "BothCul.setPayloadUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6|
    both.setPayloadUncheckedDir(.foreward, .float, 1.618, 1);

    try t.expectEqual(1.618, both.getPayloadUncheckedDir(.foreward, .float, 1));
    try t.expectEqual(1.618, both.getPayloadUncheckedDir(.backward, .float, 5));

    // |0| TAG(1) |1| BYTE |2| TAG(1) |3|
    both.setPayloadUncheckedDir(.backward, .byte, 69, 2);

    try t.expectEqual(69, both.getPayloadUncheckedDir(.backward, .byte, 2));
    try t.expectEqual(69, both.getPayloadUncheckedDir(.foreward, .byte, 1));
}

test "ForeCul.checkTag" {
    var fore = try ForeCul.initBytesCapacity(ta, 8);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    fore.setTagUnchecked(.empty, 0);
    fore.setTagUnchecked(.byte, 1);
    fore.setTagUnchecked(.signed_byte, 2);
    fore.setTagUnchecked(.float, 3);
    fore.setTagUnchecked(.array, 4);
    fore.setTagUnchecked(.big_int, 5);

    try fore.checkTag(.empty, 0);
    try fore.checkTag(.byte, 1);
    try fore.checkTag(.signed_byte, 2);
    try fore.checkTag(.float, 3);
    try fore.checkTag(.array, 4);
    try fore.checkTag(.big_int, 5);

    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.empty, 5));
    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.byte, 0));
    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.signed_byte, 1));
    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.float, 2));
    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.array, 3));
    try t.expectError(ForeCul.TagError.WrongTag, fore.checkTag(.big_int, 4));
}
test "BackCul.checkTag" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    back.setTagUnchecked(.empty, 6);
    back.setTagUnchecked(.byte, 1);
    back.setTagUnchecked(.signed_byte, 2);
    back.setTagUnchecked(.float, 3);
    back.setTagUnchecked(.array, 4);
    back.setTagUnchecked(.big_int, 5);

    try back.checkTag(.empty, 6);
    try back.checkTag(.byte, 1);
    try back.checkTag(.signed_byte, 2);
    try back.checkTag(.float, 3);
    try back.checkTag(.array, 4);
    try back.checkTag(.big_int, 5);

    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.empty, 5));
    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.byte, 6));
    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.signed_byte, 1));
    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.float, 2));
    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.array, 3));
    try t.expectError(ForeCul.TagError.WrongTag, back.checkTag(.big_int, 4));
}
test "BothCul.checkTagDir" {
    var both = try BothCul.initBytesCapacity(ta, 8);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1|
    both.setTagUncheckedDir(.foreward, .empty, 0);
    try both.checkTagDir(.foreward, .empty, 0);
    try both.checkTagDir(.backward, .empty, 1);

    both.setTagUncheckedDir(.backward, .empty, 1);
    try both.checkTagDir(.foreward, .empty, 0);
    try both.checkTagDir(.backward, .empty, 1);

    // |0| TAG(1) |1| BYTE(1) |2| TAG(1) |3|
    both.setTagUncheckedDir(.foreward, .byte, 0);
    try both.checkTagDir(.foreward, .byte, 0);
    try both.checkTagDir(.backward, .byte, 3);

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6|
    both.setTagUncheckedDir(.backward, .float, 6);
    try both.checkTagDir(.foreward, .float, 0);
    try both.checkTagDir(.backward, .float, 6);
}

test "ForeCul.setVariantUnchecked" {
    var fore = try ForeCul.initBytesCapacity(ta, 32);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    // |0| TAG(1) |1| BYTE(1) |2|
    fore.setVariantUnchecked(.byte, 69, 0);
    try t.expectEqual(69, fore.getPayloadUnchecked(.byte, ForeCul.payloadIndex(0)));
    try t.expectEqual(.byte, fore.getTag(0));

    // |2| TAG(1) |3| FLOAT(4) |7|
    fore.setVariantUnchecked(.float, 3.1415, 2);
    try t.expectEqual(3.1415, fore.getPayloadUnchecked(.float, ForeCul.payloadIndex(2)));
    try t.expectEqual(.float, fore.getTag(2));
}
test "BackCul.setVariantUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 8);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| ARRAY(4) |4| TAG(1) |5|
    back.setVariantUnchecked(.array, .{ 4, 9, 16, 25 }, 5);
    try t.expectEqual(.array, back.getTag(5));
    try t.expectEqual(
        .{ 4, 9, 16, 25 },
        back.getPayloadUnchecked(.array, BackCul.payloadIndex(5)),
    );

    // |5| BYTE(1) |6| TAG(1) |7|
    back.setVariantUnchecked(.byte, 69, 7);
    try t.expectEqual(.byte, back.getTag(7));
    try t.expectEqual(69, back.getPayloadUnchecked(.byte, BackCul.payloadIndex(7)));
}
test "BothCul.setVariantUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 16);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |4| TAG(1) |5| ARRAY(4) |9| TAG(1) |10|
    both.setVariantUncheckedDir(.foreward, .array, .{ 1, 8, 27, 64 }, 4);
    try t.expectEqual(.array, both.getTagDir(.foreward, 4));
    try t.expectEqual(.array, both.getTagDir(.backward, 10));
    try t.expectEqual(.{ 1, 8, 27, 64 }, both.getPayloadUncheckedDir(
        .foreward,
        .array,
        BothCul.payloadIndexDir(.foreward, 4),
    ));
    try t.expectEqual(.{ 1, 8, 27, 64 }, both.getPayloadUncheckedDir(
        .backward,
        .array,
        BothCul.payloadIndexDir(.backward, 10),
    ));

    // |3| TAG(1) |4| BYTE(1) |5| TAG(1) |6|
    both.setVariantUncheckedDir(.backward, .byte, 69, 6);
    try t.expectEqual(.byte, both.getTagDir(.foreward, 3));
    try t.expectEqual(.byte, both.getTagDir(.backward, 6));
    try t.expectEqual(69, both.getPayloadUncheckedDir(
        .foreward,
        .byte,
        BothCul.payloadIndexDir(.foreward, 3),
    ));
    try t.expectEqual(69, both.getPayloadUncheckedDir(
        .backward,
        .byte,
        BothCul.payloadIndexDir(.backward, 6),
    ));
}

test "ForeCul.get" {
    var fore = try ForeCul.initBytesCapacity(ta, 10);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    // |0| TAG(1) |1| ARRAY(4) |5| TAG(1) |6| FLOAT(4) |10|
    fore.setVariantUnchecked(.array, .{ 0, 1, 16, 81 }, 0);
    fore.setVariantUnchecked(.float, 1.61, 5);

    try t.expectEqual(Union{ .array = .{ 0, 1, 16, 81 } }, fore.get(0));
    try t.expectEqual(Union{ .float = 1.61 }, fore.get(5));
}
test "BackCul.get" {
    var back = try BackCul.initBytesCapacity(ta, 7);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| BYTE(1) |1| TAG(1) |2| ARRAY(4) |6| TAG(1) |7|
    back.setVariantUnchecked(.byte, 69, 2);
    back.setVariantUnchecked(.array, .{ 1, 2, 3, 4 }, 7);

    try t.expectEqual(Union{ .byte = 69 }, back.get(2));
    try t.expectEqual(Union{ .array = .{ 1, 2, 3, 4 } }, back.get(7));
}
test "BothCul.getDir" {
    var both = try BothCul.initBytesCapacity(ta, 12);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| TAG(1) |7| ARRAY(4) |11| TAG(1) |12|
    both.setVariantUncheckedDir(.foreward, .float, 3.1415, 0);
    both.setVariantUncheckedDir(.backward, .array, .{ 15, 46, 23, 70 }, 12);

    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.foreward, 0));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, 6));

    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.foreward, 6));
    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.backward, 12));
}

test "ForeCul.setUnchecked" {
    var fore = try ForeCul.initBytesCapacity(ta, 10);
    defer fore.deinit(ta);

    fore.bytes.expandToCapacity();

    // |0| TAG(1) |1| ARRAY(4) |5| TAG(1) |6| FLOAT(4) |10|
    fore.setUnchecked(Union{ .array = .{ 0, 1, 16, 81 } }, 0);
    fore.setUnchecked(Union{ .float = 1.61 }, 5);

    try t.expectEqual(Union{ .array = .{ 0, 1, 16, 81 } }, fore.get(0));
    try t.expectEqual(Union{ .float = 1.61 }, fore.get(5));
}
test "BackCul.setUnchecked" {
    var back = try BackCul.initBytesCapacity(ta, 7);
    defer back.deinit(ta);

    back.bytes.expandToCapacity();

    // |0| BYTE(1) |1| TAG(1) |2| ARRAY(4) |6| TAG(1) |7|
    back.setUnchecked(Union{ .byte = 69 }, 2);
    back.setUnchecked(Union{ .array = .{ 1, 2, 3, 4 } }, 7);

    try t.expectEqual(Union{ .byte = 69 }, back.get(2));
    try t.expectEqual(Union{ .array = .{ 1, 2, 3, 4 } }, back.get(7));
}
test "BothCul.setUncheckedDir" {
    var both = try BothCul.initBytesCapacity(ta, 12);
    defer both.deinit(ta);

    both.bytes.expandToCapacity();

    // |0| TAG(1) |1| FLOAT(4) |5| TAG(1) |6| TAG(1) |7| ARRAY(4) |11| TAG(1) |12|
    both.setUncheckedDir(.foreward, Union{ .float = 3.1415 }, 0);
    both.setUncheckedDir(.backward, Union{ .array = .{ 15, 46, 23, 70 } }, 12);

    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.foreward, 0));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, 6));

    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.foreward, 6));
    try t.expectEqual(Union{ .array = .{ 15, 46, 23, 70 } }, both.getDir(.backward, 12));
}

test "ForeCul.append" {
    var fore = ForeCul{};
    defer fore.deinit(ta);

    const first_index = fore.bytes.items.len;
    try fore.append(ta, .empty);

    const second_index = fore.bytes.items.len;
    try fore.append(ta, .{ .byte = 69 });

    const third_index = fore.bytes.items.len;
    try fore.append(ta, .{ .float = 3.1415 });

    try t.expectEqual(Union.empty, fore.get(first_index));
    try t.expectEqual(Union{ .byte = 69 }, fore.get(second_index));
    try t.expectEqual(Union{ .float = 3.1415 }, fore.get(third_index));
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

    const first_fore_index = both.bytes.items.len;
    try both.append(ta, .empty);
    const first_back_index = both.bytes.items.len;

    const second_fore_index = both.bytes.items.len;
    try both.append(ta, .{ .byte = 69 });
    const second_back_index = both.bytes.items.len;

    const third_fore_index = both.bytes.items.len;
    try both.append(ta, .{ .float = 3.1415 });
    const third_back_index = both.bytes.items.len;

    try t.expectEqual(Union.empty, both.getDir(.foreward, first_fore_index));
    try t.expectEqual(Union{ .byte = 69 }, both.getDir(.foreward, second_fore_index));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.foreward, third_fore_index));

    try t.expectEqual(Union.empty, both.getDir(.backward, first_back_index));
    try t.expectEqual(Union{ .byte = 69 }, both.getDir(.backward, second_back_index));
    try t.expectEqual(Union{ .float = 3.1415 }, both.getDir(.backward, third_back_index));
}

test "ForeCul.iterate" {
    var fore = ForeCul{};
    defer fore.deinit(ta);

    try fore.append(ta, .empty);
    try fore.append(ta, .{ .byte = 69 });
    try fore.append(ta, .{ .signed_byte = -1 });
    try fore.append(ta, .{ .float = 3.1415 });
    try fore.append(ta, .{ .array = .{ 1, 2, 4, 8 } });

    var iter = fore.iterate();

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

    var iter = both.iterateDir(.foreward);

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
    var fore = ForeCul{};
    defer fore.deinit(ta);

    try t.expectEqual(null, fore.resolveIndex(0));

    try fore.append(ta, .empty);
    try t.expectEqual(0, fore.resolveIndex(0));

    try fore.append(ta, .{ .big_int = 1000_000_000_000_000_000_000 });
    try t.expectEqual(1, fore.resolveIndex(1));

    try fore.append(ta, .{ .float = 24.60 });
    try t.expectEqual(34, fore.resolveIndex(2));
    try t.expectEqual(Union{ .float = 24.60 }, fore.get(34));

    try t.expectEqual(null, fore.resolveIndex(3));
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

    try t.expectEqual(null, both.resolveIndexDir(.foreward, 0));
    try t.expectEqual(null, both.resolveIndexDir(.backward, 0));

    try both.append(ta, .empty);
    try t.expectEqual(0, both.resolveIndexDir(.foreward, 0));
    try t.expectEqual(1, both.resolveIndexDir(.backward, 0));

    try both.append(ta, .{ .big_int = 31415 });
    try t.expectEqual(1, both.resolveIndexDir(.foreward, 1));
    try t.expectEqual(Union{ .big_int = 31415 }, both.getDir(.foreward, 1));
    try t.expectEqual(35, both.resolveIndexDir(.backward, 0));
    try t.expectEqual(Union{ .big_int = 31415 }, both.getDir(.backward, 35));
}

test "ForeCul.insertVariant" {
    var fore = ForeCul{};
    defer fore.deinit(ta);

    try fore.insertVariant(ta, 0, .empty, {});
    try t.expectEqual(Union.empty, fore.get(0));

    try fore.insertVariant(ta, 1, .byte, 69);
    var iter = fore.iterate();

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    try fore.insertVariant(ta, iter.idx, .array, .{ 0, 1, 32, 243 });
    iter = .init(&fore);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 0, 1, 32, 243 } }, iter.next());
    try t.expectEqual(null, iter.next());

    const idx = fore.resolveIndex(2) orelse return error.UnexpectedNull;
    try fore.insertVariant(ta, idx, .float, 3.1415);
    iter = .init(&fore);

    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, iter.next());
    try t.expectEqual(Union{ .array = .{ 0, 1, 32, 243 } }, iter.next());
    try t.expectEqual(null, iter.next());

    try fore.insertVariant(ta, 0, .big_int, 35148_3773);
    iter = .init(&fore);

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

    try both.insertVariantDir(.foreward, ta, 0, .empty, {});
    try t.expectEqual(Union.empty, both.getDir(.foreward, 0));

    try both.insertVariantDir(.backward, ta, 6, .float, 1.618);
    try t.expectEqual(Union{ .float = 1.618 }, both.getDir(.foreward, 0));

    try both.insertVariantDir(.backward, ta, both.bytes.items.len + 3, .byte, 69);

    var iter = both.iterateDir(.foreward);

    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(Union.empty, iter.next());
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());
}

test "ForeCul.remove" {
    var fore = ForeCul{};
    defer fore.deinit(ta);

    try fore.append(ta, .empty);
    fore.remove(0);

    var iter = fore.iterate();
    try t.expectEqual(null, iter.next());

    try fore.append(ta, .{ .byte = 69 });
    try fore.append(ta, .{ .float = 1.618 });
    try fore.append(ta, .{ .signed_byte = 42 });

    iter = fore.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .float = 1.618 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(null, iter.next());

    var index = fore.resolveIndex(1) orelse return error.UnexpectedNull;
    fore.remove(index);

    iter = fore.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(Union{ .signed_byte = 42 }, iter.next());
    try t.expectEqual(null, iter.next());

    index = fore.resolveIndex(1) orelse return error.UnexpectedNull;
    fore.remove(index);

    iter = fore.iterate();
    try t.expectEqual(Union{ .byte = 69 }, iter.next());
    try t.expectEqual(null, iter.next());

    fore.remove(0);
    iter = fore.iterate();
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

    var fore_iter = both.iterateDir(.foreward);

    try t.expectEqual(Union{ .float = 3.1415 }, fore_iter.next());
    try t.expectEqual(Union{ .byte = 69 }, fore_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, fore_iter.next());
    try t.expectEqual(Union.empty, fore_iter.next());
    try t.expectEqual(null, fore_iter.next());

    var back_iter = fore_iter.reverse();

    try t.expectEqual(Union.empty, back_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, back_iter.next());
    try t.expectEqual(Union{ .byte = 69 }, back_iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, back_iter.next());
    try t.expectEqual(null, back_iter.next());

    var index = both.resolveIndexDir(.foreward, 1) orelse return error.UnexpectedNull;
    both.removeDir(.foreward, index);
    fore_iter = .init(&both);

    try t.expectEqual(Union{ .float = 3.1415 }, fore_iter.next());
    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, fore_iter.next());
    try t.expectEqual(Union.empty, fore_iter.next());
    try t.expectEqual(null, fore_iter.next());

    index = both.resolveIndexDir(.backward, 0) orelse return error.UnexpectedNull;
    both.removeDir(.backward, index);
    back_iter = .init(&both);

    try t.expectEqual(Union{ .array = .{ 23, 29, 31, 37 } }, back_iter.next());
    try t.expectEqual(Union{ .float = 3.1415 }, back_iter.next());
    try t.expectEqual(null, back_iter.next());
}
