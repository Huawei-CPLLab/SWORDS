SWORDS (SWift ORganic Data Structures) contains a few high performance data structure implemented in pure Swift.
They are "organic" in the sense the performance critical code are not delegated to another language like C, as
some other implementations do.

# SwiftHashtable

A hash table implementation in Swift 3.0 based on associative arrays and Fast Probing.

As a major difference from the official Swift Dictionary implementation, aside 
from quadratic probing instead of linear probing during insertion and resizing, 
I use a novel algorithm (to my best knowledge) to speed up probing while searching 
or deleting a key that had collision with other keys. I name this algorithm "Fast Probing". 

## Fast Probing in details:

* During insertion of a key-value pair, we hash the key to find an "collision-free" index, 
this is the index in the associative arrays that the key-value pair should be inserted if 
there is no collision.

* In the case of collisions, we use [quardartic probing](https://en.wikipedia.org/wiki/Quadratic_probing) 
to find an alternative index for inserting the key-value pair. Then we append the alternative index to
the "relocated-to" list for that "collision-free" index. For example, if the hash value of a key is 5, 
but we inserted the key-value pair to index 8 because of collisions, then the relocated-to list for index
5 will be [8]. Later on, when another key-value pair arrives, with the hash value of the key being 5 again,
and is inserted to index 11 due to collisions, the relocated-to list for index 5 will be [8, 11].

* While deleting a key-value pair, we check the index at which the key-value pair was located, and use the
relocated-to list for that index to decide whether we want to fill the hole left by the deletion. The key-value
pair at the last index in the relocated-to list is moved to the hole. The hole-filling process repeats
until the location we just moved from has an empty relocated-to list. Continue the example in 2), when key-value
pair at index 5 is deleted, we move key-value pair at index 11 into index 5, and contine filling index 11 if
it has a non-empty relocated-to list, and so on.

* While searching for a key with collisions, instead of using linear or quadratic probing which has an upper 
bound of the table size, we traverse the relocated-to list to decide whether the key exists or not, and at where 
if it does. In practice, we found the sizes of relocated-to lists are mostly limited to 20 even with high 
degree of collisions.

In theory, Fast Probing should result in:
* faster lookups because the search space is reduced to the relocated-to list
* faster deletions because each hole-filling only takes O(1) as opposed O(N) in some other implementations
* slower insertions because of the extra work on relocated-to list
* slower table resizings due to the extra work on relocated-to list 
* More memory usages because of the relocated-to list

Overall, the pros seem to outweight the cons. With a fixed number of insertions,
bundled with a random number of deletions, updates, and lookups, this implementation 
shows great performance gain (in the range of 10%-30%) over the official Swift Dictionary. 
However, I noticed the gains are shrinked when 1) the keys have less collisions and/or 
2) there are less deletions.

When compiled with -D THREADSAFE, the hash table is thread safe.

# Queue

Queue has the basic operations, following the protocol
```swift
public protocol Queue {
  associatedtype T
  func enqueue(item:T)
  func dequeue() -> T?
  func remove()->T
  func isEmpty()->Bool
  func peek()->T?
}
```

There different queues are implemented
* ArrayQueue: Uses Swift's Array as storage. The performance is not good, and it is for demo purpose.
* ListQueue: Use a linked list as storage. Good performance.
* FastQueue: Use UnsafeMutablePointer as storage. The best performance.

# Build SwiftDataStructure

Current implementation targets `Ubuntu 15.10`. `Ubuntu 14.4` is also tested.

## Install **swift** 

Install Swift 3.0 Release [Swift 3.0]("https://swift.org/download/")


## Compile

SwiftDataStructure uses standard [swift package manager]("https://github.com/apple/swift-package-manager"):

*	 swift build, or
*    swift build -Xswiftc -DTHREADSAFE (to build a thread-safe hash table)

# Testing

Use the following command to build and test

	swift build && swift test

# Performance

Our experiments show Hash table implementation is on average ~25% faster than Dictionary.

Number of entries | Speed up over Dictionary
------------ | ------------------------
10           | 23.5%
100          | 20.6%
1,000        | 34.1%
10,000       | 17.6%
100,000      | 22.2%
1000,000     | 24.8%
10,000,000   | 34.2%
------------ | -------------------------
Mean         | 25.3%

# Usage

The hash table can be used the same way as Dictionary in the Swift standard library. For example:
```
// Create a hash table of (String, Int) pairs. The initial size 8 is optional.
var ht = Hashtable<String, Int>(count: 8)

// Add or update entries
ht["Two"] = 2                        // Add, the short way
ht["Two"] = 3                        // Update
ht.set(key:"Sixteen", value:16)      // Add, the verbose way

// Delete entries
Bool removed = ht.remove(key:"Two")  // the short way
removed = ht.remove(key:"One")       // will return false as "One" is not found as a key
ht.removeValue(forKey: "two")        // the verbose way

// Lookup entries
if let v = table["Sixteen"] {        // the short way
   ... do something with v ...
}
let w = ht.get(key: "Three")         // the verbose way

// Query how many entries are in the hash table
let size = ht.count

// Check if hash table is empty
let empty = ht.isEmpty()

// traverse the keys (unsorted)
forEachKey({(key) in {
   ... do something with key ...
}

// traverse the values (unsorted)
forEachValue({(value) in {
   ... do something with value ...
}

// traverse the key-value pairs (unsorted)
forEach({(key, value) in {
   ... do something with key and value ...
}

// retrieve keys as a sorted Array
for key in ht.sortedKeys(lessThan: {$0 < $1}) {
    ... do something with keys in order ...
}

// retrieve values as a sorted Array
for value in ht.sortedValues(lessThan: {$0 < $1}) {
    ... do something with values in order ...
}
```

Check the examples in `Tests/SwiftHashtableTests/` and `Tests/QueueTests/` for more sample usages.

