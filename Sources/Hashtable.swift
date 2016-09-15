// Copyright (C) 2016. Huawei Technologies Co., Ltd. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//  Created by Xuejun Yang on 8/27/16
//

import Glibc

public struct Hashtable<K: Hashable, V> : CustomStringConvertible {
    private var tableSize = 2
    private var elementNum = 0

    public var debug = false;

    #if THREADSAFE
    // Thread safe read-write lock
    var lock = pthread_rwlock_t()
    #endif

    // Undelying arrays, do not modify them directly

    private var keys : UnsafeMutablePointer<K>
    private var values : UnsafeMutablePointer<V>
    private var occupied: UnsafeMutablePointer<Bool>
    private var relocatedTo: UnsafeMutablePointer<[Int]>

    // Hash table default construction
    // - returns: empty hash table

    public init(count: Int = 2) {
        while tableSize < count  { tableSize <<= 1 }
        self.keys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        self.values = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        self.occupied = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        self.relocatedTo = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (self.occupied + i).initialize(to: false)
            (self.relocatedTo + i).initialize(to: [])
        }

        #if THREADSAFE
        pthread_rwlock_init(&lock, nil)
        #endif
    }

    // Property about the number of elements in the hash table
    var count: Int {
        return elementNum
    }

    // Insert an key-value pair of type (K, V) into the table
    // 
    // - parameter key : key to insert
    // - parameter value: value to insert
    // - parameter origIndex: the collision-free index for the key
    // - parameter finalIndex: the final index used for insertion

    @inline(__always)
    mutating private func insertPair(key: K, value: V, origIndex: Int, finalIndex: Int) {
        // set the occupied flag, key and value
        (self.keys + finalIndex).initialize(to: key)
        (self.values + finalIndex).initialize(to: value)
        self.occupied[finalIndex] = true

        self.elementNum += 1
        
        // append to the relocated-to list of the conflict-free index
        if finalIndex != origIndex {
            self.relocatedTo[origIndex].append(finalIndex) 
        }
        // Grow the table if we are about to use up space (70% load)
        if self.count >= (tableSize * 7 / 10) {
            enlarge()
        }
    }

    // Push an key-value pair of type (K, V) into the table
    // 
    // - parameter key : key to insert
    // - parameter value: value to insert
    // - return: whether a new entry is created or not

    mutating public func set(key: K, value: V) -> Bool {
        #if THREADSAFE
        pthread_rwlock_wrlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        #endif

        let sizeMinus1 = (tableSize - 1)
        var index = key.hashValue & sizeMinus1
        let origIndex = index
        
        // case 1: the desired bucket is empty -> insert new entry
        if !self.occupied[index] {
            insertPair(key: key, value: value, origIndex: origIndex, finalIndex: index)
            return true
        }

        // case 2: the desired bucket is taken by the same key -> update value
        if self.keys[index] == key {
            //if debug { print("case 2: found existing key at \(index)") }
            self.values[index] = value
            return false
        }
            
        // case 3: collision! -> use relocatedTo list to find real location
        for i in self.relocatedTo[origIndex] {
            if self.keys[i] == key {
                self.values[i] = value
                return false;
            }
        }
        
        // case 4: collision! -> use quadratic probing to find an available bucket
        var probe = 0
        while true {
            probe += 1
            index = (index + probe) & sizeMinus1

            if !self.occupied[index] {
                insertPair(key: key, value: value, origIndex: origIndex, finalIndex: index)
                return true
            }
            assert(probe < tableSize, "Failed to grow the table earlier")
        }
    }
    

    // Find the index in the associative array for a given key

    // - parameter key : key to look up
    // - return: the index in the associative array. -1 if not found

    private func findIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)
        
        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        } 
        
        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key {
            return index
        }
            
        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    // Find the index in the associative array for a given key, and 
    // preemptively remove it from the relocated-to list

    // - parameter key : key to look up
    // - return: the index in the associative array. -1 if not found

    mutating private func findAndRemoveRelocateIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)
        
        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        } 
        
        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key {
            return index
        }
            
        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                self.relocatedTo[index].remove(at: i) 
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    // Retrieve the value associated with a key

    // - parameter key : key to look up

    #if THREADSAFE
    mutating public func get(key: K) -> V? {
        #if THREADSAFE
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        #endif

        let index = findIndex(key:key)
        if index != -1 { return self.values[index] }
        return nil
    }
    #else
    public func get(key: K) -> V? {
        let index = findIndex(key:key)
        if index != -1 { return self.values[index] }
        return nil
    }
    #endif
    

    // Remove the key-value pair identified by the key

    // - parameter key : key to look up
    // - return: true if deleted. false if not found

    mutating public func remove(key: K) -> Bool {
        #if THREADSAFE
        pthread_rwlock_wrlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        #endif

        var index = findAndRemoveRelocateIndex(key:key)
        if index != -1 {
            elementNum -= 1

            // move a collided entry to here if there is one
            while !self.relocatedTo[index].isEmpty {
                let relocatedToIndex = self.relocatedTo[index].popLast()!

                // move the KV pair
                self.keys[index] = self.keys[relocatedToIndex]
                self.values[index] = self.values[relocatedToIndex]

                // deal with the hole left by the above moving
                index = relocatedToIndex
            }
            // mark the bucket as empty
            self.occupied[index] = false
            // free the value and key
            (self.values + index).deinitialize()
            (self.keys + index).deinitialize()

            // TODO: check if we should shrink the table
            return true
        }
        return false
    }

    // Remove the key-value pair identified by the key.
    // Provide the same API as Dictionary.

    // - parameter forKey : key to look up
    mutating public func removeValue(forKey: K) {
        let _ = remove(key: forKey)
    }

    // Method to determine if the table is empty
    
    // - returns : returns true if the table is empty

    #if THREADSAFE
    mutating public func isEmpty() -> Bool {
        #if THREADSAFE
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        #endif

        return self.count == 0
    }
    #else
    public func isEmpty() -> Bool {
        return self.count == 0
    }
    #endif
    

    // Method to visit all key-value pairs with a closure

    #if THREADSAFE
    mutating public func forEach(_ lambda: (K, V)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }

        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i], values[i])
            }
        }
    }
    #else
    public func forEach(_ lambda: (K, V)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i], values[i])
            }
        }
    }
    #endif

    // Method to visit all keys with a closure

    #if THREADSAFE
    mutating public func forEachKey(_ lambda: (K)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }

        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i])
            }
        }
    }
    #else
    public func forEachKey(_ lambda: (K)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i])
            }
        }
    }
    #endif

    // Method to visit all values with a closure

    #if THREADSAFE
    mutating public func forEachValue(_ lambda: (V)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }

        for i in 0..<tableSize {
            if occupied[i] {
                lambda(values[i])
            }
        }
    }
    #else
    public func forEachValue(_ lambda: (V)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(values[i])
            }
        }
    }
    #endif
    
    // Method to 4x the capacity of the table. All entries need to be copied

    mutating private func enlarge() { return enlarge (toSize: tableSize * 4) }

    // Method to increase the capacity of the table to a given size. The size is normalized to 2 ^ n

    mutating private func enlarge(toSize: Int) {
        #if DEBUG 
        print("Table before enlarging: \(self)")
        #endif

        let origSize = tableSize
        while tableSize < toSize  { tableSize <<= 1 }
        #if DEBUG  
        print("Table size will be \(tableSize)")
        #endif

        // prepare clean arrays
        let newKeys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        let newValues = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        let newFlags = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        let newRelocations = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (newFlags + i).initialize(to: false)
            (newRelocations + i).initialize(to: [])
        }

        for i in 0..<origSize {
            if self.occupied[i] {
                let key = self.keys[i]
                let value = self.values[i]
                #if DEBUG 
                print("inserting " + String(describing: key) + ":" + String(describing: value))
                #endif

                var probe = 0;                      // how many times we've probed
                let sizeMinus1 = tableSize - 1;
                var index = key.hashValue & sizeMinus1;
                let origIndex = index

                // Shortcut???: the length of the relocation array tells us how many conflicts 
                // we've had. Skip checking the already relocated-to buckets
                //var probe = newRelocations[origIndex].count
                //if probe > 0 {
                //    index = newRelocations[origIndex].last!
                //}
                while probe < tableSize {
                    #if DEBUG  
                    print("table size: \(tableSize), size-1: \(sizeMinus1), index: \(index), probe: \(probe)") 
                    #endif

                    // If not occupied, take it
                    if !newFlags[index] { break }

                    // for next probing
                    probe += 1
                    index = (index + probe) & sizeMinus1 
                }       
                assert(probe < tableSize, "Error: Hash table gets full during enlarging");

                // The 3 things we need to do when taking an empty bucket:
                // 1) set the occupied flag
                // 2) set the key and value
                // 3) append to the relocated-to list of the conflict-free index
                (newKeys + index).initialize(to: key)
                (newValues + index).initialize(to: value)
                newFlags[index] = true
                if probe != 0 {
                    newRelocations[origIndex].append(index)
                }
            }
        }

        // reclaim old arrays
        self.keys.deallocate(capacity: origSize)
        self.values.deallocate(capacity: origSize)
        self.occupied.deallocate(capacity: origSize)
        self.relocatedTo.deallocate(capacity: origSize)

        // point to new arrays
        self.keys = newKeys
        self.values = newValues // TODO: make array copy more efficient with ownership
        self.occupied = newFlags
        self.relocatedTo = newRelocations

        #if DEBUG
        print("Table after enlarging: \(self)")
        #endif
    }

    // Method to implement CustomStringConvertible

    public var description: String {
		get {
			if elementNum == 0 { return "[]"}
            var str = "["
            for i in 0..<tableSize {
                if occupied[i] {
                    let key = self.keys[i]
                    let value = self.values[i]
                    if str != "[" { str += "\n"}
                    str += String(describing: key) + ": " + String(describing: value)
                    //if debug { str += ". Index: \(i)" }
                }
            }
            str += "\n]"
            return str
		}
	}

    // Method to calculate collision rate as: 
    //    1) the size of relocatedTo array for each bucket represents the collisions found for that bucket index
    //    2) Collision Rate = Sum(relocatedTo-array-sizes) / elementNum
    // Caution: don't call this in the middle of multi-thread hash table operations as it is non-thread-safe 

    public func collisionRate() -> Int {
        var collisions = 0
        for i in 0..<tableSize {
            collisions += self.relocatedTo[i].count

            #if DEBUG
            print("\(i)....\(self.relocatedTo[i])....\(self.occupied[i])")
            #endif
        }
        return collisions * 100 / self.elementNum
    }

    // Method to enable subscripted read/write, such as "hashTable["aaa"] = hashTable["bbb"] + 1"

    #if THREADSAFE
    subscript(key: K) -> V? {
        mutating get {
            return get(key: key)
        }
        
        set {
            if let value = newValue {
                let _ = set(key: key, value: value)
            } else {
                let _ = remove(key: key)
            }
        }
    }
    #else
    subscript(key: K) -> V? {
        get {
            return get(key: key)
        }
        
        set {
            if let value = newValue {
                let _ = set(key: key, value: value)
            } else {
                let _ = remove(key: key)
            }
        }
    }
    #endif
} 




