# ⚡ Cul

The `CompactUnionList`, or `cul` (which is French for "ass" btw) data structure is a blazingly small collection of unions that gives up useless operations (like any kind of random access) in order to optimize its size.

## 🍰 Why not an slice?

The use-case of a `cul` is niche. It's useful when you have a big list of unions, that you don't access them often and/or preferably do so in the same (fifo) or opposite (filo) order they were declared in. In this kind of case, even though the access to the items of the list is a little more costly than that of a slice, storing them will require a lot less space, especially when there's a big size difference between the smallest and biggest variant. This memory efficiency could save you from some cache misses and result in a better execution speed in addition to the lower memory consumption.

It's very likely that it won't happen and you'll be better off using a `std.MultiArrayList` or even a dumb `std.ArrayList`. Do the benchmark.

## ⚙️ How does it work?

There are three similar heap-allocated data-structure that you could use for storing your unions:

1. `std.MuliArrayList`, the best in most cases,
2. `std.ArrayListUnmanaged`, the simplest,
3. `CompactUnionList`, the most complicated, less flexible and less efficient most of the time.

Let's compare their storing strategy:

### `std.ArrayListUnmanaged`

The array list will contiguously store the union themselves. A union is made up of a tag and a payload that must be able to contain the greatest variant type of the union type.

First, there's the tag type. It's usually just a byte because there's rarely a need for more than 256 variants. After the tag type, there's padding, because the payload must have the alignment of the variant type with the biggest alignment. Then there's the payload. If the variant isn't the of the biggest variant type, there's unused bytes because it must be able to store the biggest variant. Then there's padding bytes because the next union instance must start with the same alignment.

- tag,
- tag-to-payload padding ,
- payload,
- unused,
- payload-to-union padding.

This method stores a lot of useless bytes.

### `std.MultiArrayList`

The multi array list will store the tags and the payloads in separate lists.

The tag list will usually have no padding, since it rarely goes over a byte, and even if it does, two bytes is still a power of two and doesn't require additional padding.

- tag,
- tag-to-tag padding,

The payload still need the same unused bytes to be able to store the biggest payload. But the padding is can be smaller since it only need to go to another payload and not the entire union.

- payload,
- unused,
- payload-to-payload padding,

This result in a more efficient padding, even though there's still the same amount of unused bytes from the payload size difference. The `std.MultiArrayList` support the same operations as the `std.ArrayListUnmanaged`, except for subslicing, with a negligible amount of overhead when accessing its elements.

### `CompactUnionList`

The cul won't store anything else than the tag and the payload. No padding or unused bytes. If the cul is foreward, it stores the tag first, if it's backward it stores the payload first. If it's bothward, it'll store the tag twice: once before and once after the payload. This might seem inefficient, but it'll still be better than even the multi array list as long as the size difference between the biggest and smallest variant is bigger than the tag (which is often just one byte).

The problem is that most of the payloads, and sometimes the even the tags, aren't properly aligned so accessing an item will be less efficient even than with a muli array list. But this is orders of magnitude more efficient than a cache miss still.

The real problem is that the location of an item can't be deduced anymore from its index alone, since all items are stored using a varying amount of bytes. You can more-or-less efficiently iterate over them though. Since you can easily find the next tag, and therefore its size. If the tag is stored first, you can iterate forewards (first-in-first-out), if the tag is stored last you can iterate backwards (first-in-last-out), if there's a tag both before and after each payload, you can iterate bothwards.

### Comparison

|                    | `CompactUnionList`        | `std.MultiArrayList`              | `std.ArrayList`            |
| ------------------ | ------------------------- | --------------------------------- | -------------------------- |
| Storage            | byte-by-byte              | tag and payload in separate lists | in a contiguous list       |
| Unused bytes       | 🟢 none: `O(1)`           | 🔴 yes: `O(nD)`                 | 🔴 yes: `O(nD)`              |
| Padding            | 🟢 none: `O(1)`           | 🟠 decent `O(n(p+t))`           | 🔴 terrible `O(n(v+t))`      |
| Memory Consumption | 🟢 most efficient: `O(n)` | 🟠 decent `O(n(p+t+u))`         | 🔴 terrible `O(n(v+t+u))`    |
| Random Access      | 🔴 terrible: `O(nc)`      | 🟢 efficient `O(1)`             | 🟢 most efficient `O(1)`     |
| Iteration          | 🟠 decent: `O(c)`         | 🟢 efficient `O(1)`             | 🟢 most efficient `O(1)`     |

- n: number of items,
- u: difference between greatest and smallest variant,
- v: variant padding,
- t: tag padding,
- p: payload padding,
- c: compression/decompression complexity

### Example

Let's consider a union type and a list of all variants.

```zig
const Union = union(enum) {
    empty,
    byte: u8,
    word: u16,
    int: u32,
    long: u64,
};
```

#### `std.ArrayListUnmanaged`

A the largest payload is that of the `long` variant (64 bits/8 bytes), and there's an 8 bit/1 byte tag. So each union should be 128 bits/16 bytes. Let's see what `.{ .empty, .byte, .word, .int, .long }` looks like in memory.

```
|0x00| TAG(1):empty |0x01| PADDING(7) |0x08| EMPTY(0) |0x08| UNUSED(8) |0x10|
|0x10| TAG(1):byte  |0x11| PADDING(7) |0x18| BYTE(1)  |0x19| UNUSED(7) |0x20|
|0x20| TAG(1):word  |0x21| PADDING(7) |0x28| WORD(2)  |0x2A| UNUSED(6) |0x30|
|0x30| TAG(1):int   |0x31| PADDING(7) |0x38| INT(4)   |0x3C| UNUSED(4) |0x40|
|0x40| TAG(1):long  |0x41| PADDING(7) |0x48| LONG(8)  |0x50| UNUSED(0) |0x50|
```

Here, we can clearly see what's happening with the padding of the tag. That's what `std.MultiArrayList` takes care of.

We used 640 bits/80 bytes.

#### `std.MultiArrayList`

```
|0| TAG(1):empty |1|
|1| TAG(1):byte  |2|
|2| TAG(1):word  |3|
|3| TAG(1):int   |4|
|4| TAG(1):long  |5|

|0x00| EMPTY(0) |0x00| UNUSED(8) |0x08|
|0x08| BYTE(1)  |0x09| UNUSED(7) |0x10|
|0x10| WORD(2)  |0x12| UNUSED(6) |0x18|
|0x18| INT(4)   |0x1B| UNUSED(4) |0x20|
|0x20| LONG(8)  |0x28| UNUSED(0) |0x28|
```

Here, we used 40 bits/5 bytes for the tags (no padding required), and 320 bits/40 bytes for the payloads (no padding either but unused bytes).

We used 360 bits/45 bytes which is already a great improvement. But there's still unused bytes (and we're lucky there's no additional padding for the payload (that could happen too with the tag (but I doubt you've encountered this case))).

#### `CompactUnionList`

```
|0x00| TAG(1):empty |0x01| EMPTY(0) |0x01|
|0x01| TAG(1):byte  |0x02| BYTE(1)  |0x03|
|0x03| TAG(1):word  |0x04| WORD(2)  |0x06|
|0x06| TAG(1):int   |0x07| INT(4)   |0x0B|
|0x0B| TAG(1):long  |0x0C| LONG(8)  |0x24|
```

Here we used 192 bits/24 bytes.

## 📃 License

MIT License

Copyright (c) 2025 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
