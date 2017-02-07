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

//  Created by Xuejun Yang on 9/14/16
//

import XCTest
@testable import SwiftDataStructure

#if os(OSX) || os(iOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

/// Wrapper function for both Linux and Mac
func randomInt()->Int {
    #if os(Linux)
        return random()
    #else
        return Int(arc4random())
    #endif
}


// Class to represent objects stored in the hash table as values
final class MyVal : CustomStringConvertible {
    public var i = 0
    init(_ input:Int) { i = input }

    public var description: String {
		get { return "\(i)" }
    }
}

// Struct to represent objects stored in the hash table as keys
struct MyKey : Hashable, CustomStringConvertible {
    public var s = ""
    init(_ input:String) { s = input }

    public var hashValue: Int { get { return s.hashValue}}

    public var description: String {
		get { return s }
    }
}

func ==(x: MyKey, y: MyKey) -> Bool {
    return x.s == y.s
}

class SwiftHashtableTests: XCTestCase {

    // Method to unit test the hash table with small number of entries

    private func smallTest() {
        var ht = Hashtable<String, Int>(count: 8)
        let names = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen"]
        var i = 0;
        for name in names {
            let _ = ht.set(key:name, value:i)
            i += 1
        }

        let _ = ht.remove(key:"Sixteen")
        let _ = ht.remove(key:"Eight")

        let _ = ht.set(key:"Sixteen", value:16)

        assert(ht.get(key:"Five")! == 5, "Wrong value at 5")
        assert(ht.get(key:"Eight") == nil, "Wrong value at 8")

        print(ht)

        let _ = ht.remove(key:"Five")
        let _ = ht.remove(key:"Six")
        let _ = ht.remove(key:"Ten")
        let _ = ht.remove(key:"Twelve")
        let _ = ht.remove(key:"Thirteen")
        let _ = ht.remove(key:"Three")
        let _ = ht.remove(key:"Fifteen")
        let _ = ht.remove(key:"Fourteen")
        let _ = ht.remove(key:"Two")
        let _ = ht.remove(key:"One")
        let _ = ht.remove(key:"Zero")

        assert(ht.get(key:"Four")! == 4, "Wrong value at 4")
        assert(ht.get(key:"Ten") == nil, "Wrong value at 10")

        print(ht)
    }

    var allKeys = [String]()
    var allValues = [Int]()
    var deleteIndices = [Int]()
    var lookupIndices = [Int]()
    var updateIndices = [Int]()
    let allLetters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    func generateKVs(count: Int) {
        allKeys = []
        allValues = []
        // create the random key-value pairs
        for _ in 0..<count {
            var index = allLetters.index(allLetters.startIndex, offsetBy: randomInt() % 52)
            var key : String = String(allLetters[index])
            index = allLetters.index(allLetters.startIndex, offsetBy: randomInt() % 52)
            key += String(allLetters[index])
            index = allLetters.index(allLetters.startIndex, offsetBy: randomInt() % 52)
            key += String(allLetters[index])

            allKeys.append(key)

            allValues.append(randomInt())
        }
        #if DEBUG
        print(allKeys) 
        #endif
    }

    func generateDeleteAndLookupIndices(count : Int) {
        deleteIndices = []
        lookupIndices = []
        updateIndices = []

        let num1 = randomInt() % count
        for _ in 0..<num1 {
            deleteIndices.append(randomInt() % count)
        }
        //print("Will delete \(num1) keys")

        let num2 = randomInt() % count
        for _ in 0..<num2 {
            lookupIndices.append(randomInt() % count)
        }
        //print("Will lookup \(num2) keys")
    
        let num3 = randomInt() % count
        for _ in 0..<num3 {
            updateIndices.append(randomInt() % count)
        }
        //print("Will update \(num3) keys")
    }

    var insertOnly = false      // If true, we only do insertions to the table, nothing else
    var counter = 0
    var table = Hashtable<MyKey, MyVal>()
    var dict = Dictionary<MyKey, MyVal>()
    func perfTestDictionary(count:Int) -> (Int, Int) {
        var sum = 0 
        let start = clock()

        // measure timing for the standard Dictionary
        dict = Dictionary<MyKey, MyVal>()

        // insert half of the pairs
        let mid = count/2
        for i in 0..<mid {
            dict[MyKey(allKeys[i])] = MyVal(allValues[i])
        }

        //print("Hashtable: after first insert: \(dict.count())")

        if !insertOnly {
            // delete random number of entries in the table
            for index in deleteIndices {
                dict.removeValue(forKey: MyKey(allKeys[index]))
            }
        }
   
        // insert 2nd half of the pairs
        for k in mid..<count {
            dict[MyKey(allKeys[k])] = MyVal(allValues[k])
        }

        // update random number of values
        if (!insertOnly) {
            for index in updateIndices {
                let key = MyKey(allKeys[index])
                dict[key] = MyVal(0)
            }
        }

        // Sum up random number of values
        if !insertOnly {
            // lookup random number of entries
            for index in lookupIndices {
                let key = MyKey(allKeys[index])
                if let v = dict[key] {
                    sum = sum &+ v.i 
                }
            }
        }

        let end = clock()

        print("Time used with Dictionary filled with objects: \((end-start)/1) us")
        return (sum, Int(end-start));
    }

    func perfTestHashtable(count:Int) -> (Int, Int) {
        var sum = 0
        let start = clock()

        // measure timing for this implementation
        table = Hashtable<MyKey, MyVal>()

        // insert half of the pairs
        let mid = count/2
        for i in 0..<mid {
            table[MyKey(allKeys[i])] = MyVal(allValues[i])
        }

        //print("Hashtable: after first insert: \(table.count())")

        if !insertOnly {
            // delete random number of entries in the table
            for index in deleteIndices {
                let _ = table.remove(key: MyKey(allKeys[index]))
            }
        }
   
        // insert 2nd half of the pairs
        for k in mid..<count {
            table[MyKey(allKeys[k])] = MyVal(allValues[k])
        }

        // update random number of values
        if (!insertOnly) {
            for index in updateIndices {
                let key = MyKey(allKeys[index])
                table[key] = MyVal(0)
            }
        }

        // Sum up random number of values
        if !insertOnly {
            // lookup random number of entries
            for index in lookupIndices {
                let key = MyKey(allKeys[index])
                if let v = table[key] {
                    sum = sum &+ v.i 
                }
            }
        }

        let end = clock()

        print("Time used with Hashtable filled with objects: \((end-start)/1) us. Collison rate: \(table.collisionRate())%")
        return (sum, Int(end-start));
    }

    // Random test the hash table and compare results with Dictionary

    private func randomTest(_ count : Int) {
        insertOnly = false
        print("count is \(count).")

        let loops = 100
        var totalTime1 = 0
        var totalTime2 = 0
        for i in 0..<loops {
            counter = i
            generateKVs(count: count)
            generateDeleteAndLookupIndices(count: count)

            let (sum1, time1) = perfTestDictionary(count: count)
            let (sum2, time2) = perfTestHashtable(count: count)
            print("Iteration \(i): \(sum1) vs \(sum2)")

            XCTAssertEqual(sum1, sum2)

            #if DEBUG
            if (sum1 != sum2) {
                print(allKeys)
                print(deleteIndices)
                print(lookupIndices)
                print(updateIndices)
                table.forEachKey({ (key) in 
                    if table[key]!.i != dict[MyKey(key.s)]!.i { 
                        print("mismatch: \(key), \(table[key]!.i), \(dict[MyKey(key.s)]!.i)") 
                    }
                })
            }
            #endif
            totalTime1 += time1
            totalTime2 += time2
        }
        print("Average time spent with Dictionary: \(totalTime1/loops)")
        print("Average time spent with Hashable: \(totalTime2/loops)")
    }

    private func mediumTest() { randomTest(100) }
    private func bigTest() { randomTest(1000) }

    static var allTests : [(String, (SwiftHashtableTests) -> () throws -> Void)] {
        return [
            ("smallTest", smallTest),
            ("mediumTest", mediumTest),
            ("bigTest", bigTest),
        ]
    }
}
