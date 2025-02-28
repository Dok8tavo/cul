# ⚡ Cul

The `CompactUnionList`, or `cul` (which is French for "ass" btw) data structure is a blazingly small collection of unions that gives up useless operations (like any kind of random access) in order to optimize its size.

## Why not a slice?

Using a slice/array/array list of unions will result in a lot of waste of space, especially when some variants are a lot bigger than others.

Let's consider the following union:

```zig
const Union = union(enum) {
    null,
    float: f32,
    int: i64,
};
```

The biggest payload is 64 bits (or 8 bytes) long. But you also need to store 8 bits (or 1 byte) for the tag of the union. This will result into using 128 bits (or 16 bytes), because of padding. If you use a slice/array/array list, each variant will take this size exactly. If you were to store one `.null`, one `.float` and one `.int` variant, it would look like this:


```
|0 | null  |1 | ... |8 | ...    |16|
|16| float |17| ... |20| 3.1415 |32|
|32| int   |33| ... |40| 1515   |48|
```

We used 48 bytes.

One solution to mitigate the effect is using `std.MultiArrayList`. This data structure will store the tag and the payload separatly to avoid some padding. In this case it would look like this:

```
tags:
    |0| null |1| float |2| int |3|
payloads:
    |0| ...  |8| 3.1415 |12| ... |16| 1515 |24|
```

We used 25 bytes. This is already a very good improvement, given all alignments have been respected and random access is still possible. But there's still some `...` padding here right?

Here's what the `Cul` does:

```
|0| tag:null |1| tag:float |2| payload:3.1415 |6| tag:int |7| payload:1515 |15|
```

No padding bytes and we only use 15 bytes in total. It starts being very efficient the more small variants it must hold compared to the biggest variant.

Now the elements aren't aligned correctly, so we have to either retrieve them by value or use a `*align(1) Item` pointer. Also, the byte index of the n-th element isn't known with just `n`, we need to iterate over the data structure.

In the example, I used the foreward cul that puts the tag first and therefore allow to iterate from the first element to the last (first-in-first-out). There's also the backward cul that puts the tag after the payload:

```
|0| tag:null |1| payload:3.1415 |5| tag:float |6| payload:1515 |14| tag:int |15|
```

This allow to iterate from the last element to the first (first-in-last-out). There's also the bothward cul that put a tag before and a tag after the payload, to allow iteration in both direction:

```
|0| tag:null |1| tag:float |2| payload:3.1415 |6| tag:float |7| tag:int |8| payload:1515 |16| tag:int |17| 
```

In some (statically-known) edge cases, this method of iteration might store more than a `std.MultiArrayList` or even a slice/array/array list. 

