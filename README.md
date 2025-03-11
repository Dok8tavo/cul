# ⚡ Cul

The `CompactUnionList`, or `cul` (which is French for "ass," by the way), is a blazingly small collection of unions that sacrifices useless operations (like any kind of random access) to optimize its size.

## 🍰 Why not a slice?

The use case for a `cul` is niche. It's useful when you have a large list of unions that you don't access often and/or preferably in the same (FIFO) or opposite (FILO) order in which they were declared. In such cases, even though accessing items in the list is slightly more costly than with a slice, storing them requires significantly less space—especially when there's a large size difference between the smallest and largest variant. This memory efficiency can reduce cache misses and improve execution speed in addition to lowering memory consumption.

However, in most cases, this advantage won't be significant, and you'll be better off using a `std.MultiArrayList` or even a simple `std.ArrayList`. Always benchmark before deciding.

## ⚙️ How does it work?

There are three similar heap-allocated data structures you could use to store your unions:

1. `std.MultiArrayList` – the best in most cases.
2. `std.ArrayListUnmanaged` – the simplest.
3. `CompactUnionList` – the most complicated, less flexible, and usually less efficient.

Let's compare their storage strategies:

### `std.ArrayListUnmanaged`

An array list stores the unions contiguously. A union consists of a tag and a payload, which must be large enough to contain the biggest variant type of the union.

- The tag type is usually just a byte, as more than 256 variants are rarely needed.
- After the tag, there's padding because the payload must be aligned with the variant type that has the strictest alignment requirements.
- The payload follows, but if it isn't the largest variant, there are unused bytes to ensure it can store the largest variant.
- Additional padding is added to maintain proper alignment for the next union instance.

This method stores a lot of unnecessary bytes.

### `std.MultiArrayList`

A multi-array list stores tags and payloads in separate lists.

- The tag list usually has no padding, as it rarely exceeds a byte. Even if it does, two bytes is still a power of two and won't require extra padding.
- The payload list still needs unused bytes to accommodate the largest payload, but padding is reduced since it only applies to payloads rather than entire unions.

This results in more efficient padding, though the same amount of unused bytes persists due to payload size differences. `std.MultiArrayList` supports the same operations as `std.ArrayListUnmanaged` (except for subslicing) with a negligible access overhead.

### `CompactUnionList`

The `cul` stores only the tag and the payload—no padding or unused bytes. If the `cul` is forward, it stores the tag first; if backward, it stores the payload first. If it's bothward, it stores the tag twice—once before and once after the payload. While this might seem inefficient, it still outperforms even the multi-array list as long as the size difference between the largest and smallest variant exceeds the tag size (often just one byte).

The main downside is that payloads (and sometimes even tags) may not be properly aligned, making access less efficient than in a multi-array list. However, this inefficiency is still orders of magnitude better than a cache miss.

A bigger issue is that item locations can't be deduced from their indices alone, as items take up varying amounts of space. However, iteration is still feasible since each tag provides size information. If the tag is stored first, you can iterate forward (FIFO). If stored last, you can iterate backward (FILO). If stored both before and after, you can iterate bothwards.

### Comparison

|                    | `CompactUnionList`        | `std.MultiArrayList`              | `std.ArrayListUnmanaged`    |
| ------------------ | ------------------------- | --------------------------------- | -------------------------- |
| Storage            | byte-by-byte              | tag and payload in separate lists | in a contiguous list       |
| Unused bytes       | 🟢 none: `O(1)`           | 🔴 yes: `O(nD)`                   | 🔴 yes: `O(nD)`            |
| Padding            | 🟢 none: `O(1)`           | 🟠 decent `O(n(p+t))`             | 🔴 terrible `O(n(v+t))`    |
| Memory Consumption | 🟢 most efficient: `O(n)` | 🟠 decent `O(n(p+t+u))`           | 🔴 terrible `O(n(v+t+u))`  |
| Random Access      | 🔴 terrible: `O(nc)`      | 🟢 efficient `O(1)`               | 🟢 most efficient `O(1)`   |
| Iteration          | 🟠 decent: `O(c)`         | 🟢 efficient `O(1)`               | 🟢 most efficient `O(1)`   |

- `n`: number of items
- `u`: difference between greatest and smallest variant
- `v`: variant padding
- `t`: tag padding
- `p`: payload padding
- `c`: compression/decompression complexity

### Example

Let's consider a union type and a list of all variants:

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

The largest payload is `long` (64 bits/8 bytes), and the tag is 8 bits/1 byte. Each union takes 128 bits/16 bytes.

Used memory: **80 bytes**

#### `std.MultiArrayList`

- Tags take **5 bytes** (no padding required).
- Payloads take **40 bytes** (no padding but with unused bytes).

Used memory: **45 bytes** (significant improvement)

#### `CompactUnionList`

- Eliminates unused bytes and minimizes padding.

Used memory: **24 bytes**

## 📃 License

MIT License

(c) 2025 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

