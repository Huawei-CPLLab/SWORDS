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

# Build SwiftHashtable #

Current implementation targets `Ubuntu 15.10`. `Ubuntu 14.4` is also tested.

## Install **swift** 

Install preview verison 4 or higher of [Swift 3.0]("https://swift.org/download/#previews")


## Compile Theater

SwiftHashtable uses standard [swift package manager]("https://github.com/apple/swift-package-manager"):

*	 swift build, or
*    swift build -Xswiftc -DTHREADSAFE (to build a thread-safe hash table)

# Testing #

Use the following command to build and test

	swift build && swift test

# Usage #

Check the examples in `Tests/SwiftHashtableTests/` for sample usage.

