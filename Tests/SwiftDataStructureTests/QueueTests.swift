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

//  Created by Haichuan Wang on 8/17/16
//

import XCTest
@testable import SwiftDataStructure

class QueueTests: XCTestCase {
    let n : Int = 100000

    func checkCorrect<Q:Queue>(queue:Q) where Q.T == Int {
        for i in 1...100 {
            queue.enqueue(item:i)
        }
        for i in 1...100 {
            XCTAssertEqual(i, queue.dequeue()!)
        }
    }

    func testArrayQueue() {
        checkCorrect(queue:ArrayQueue<Int>())
    }

    func testListQueue() {
        checkCorrect(queue:ListQueue<Int>())
    }

    func testFastQueue() {
        checkCorrect(queue:FastQueue<Int>(initSize:1))
    }

    func testSpeedArrayQueue() {
        let expected = (1+n)*n/2
        let queue = ArrayQueue<Int>()
        var r:Int = 0
        for i in 1...n {
            queue.enqueue(item:i)
        }
        while let v = queue.dequeue() {
            r += v
        }
        XCTAssertEqual(r, expected)
    }

    func testSpeedListQueue() {
        let expected = (1+n)*n/2
        let queue = ListQueue<Int>()
        var r:Int = 0
        for i in 1...n {
            queue.enqueue(item:i)
        }
        while let v = queue.dequeue() {
            r += v
        }
        XCTAssertEqual(r, expected)
    }

    func testSpeedFastQueue() {
        let expected = (1+n)*n/2
        let queue = FastQueue<Int>(initSize:100)
        var r:Int = 0
        for i in 1...n {
            queue.enqueue(item:i)
        }
        while let v = queue.dequeue() {
            r += v
        }
        XCTAssertEqual(r, expected)
    }


    func testSpeedFastQueueRemove() {
        let expected = (1+n)*n/2
        let queue = FastQueue<Int>(initSize:100)
        var r:Int = 0
        for i in 1...n {
            queue.enqueue(item:i)
        }
        for _ in 1...n {
            r += queue.remove()
        }

        XCTAssertEqual(r, expected)
    }

    static var allTests : [(String, (QueueTests) -> () throws -> Void)] {
        return [
            ("testFastQueue", testFastQueue),
            ("testListQueue", testListQueue),
            ("testArrayQueue", testArrayQueue),
            ("testSpeedFastQueue", testSpeedFastQueue),
            ("testSpeedFastQueueRemove", testSpeedFastQueueRemove),
            ("testSpeedListQueue", testSpeedListQueue),
            ("testSpeedArrayQueue", testSpeedArrayQueue),
        ]
    }
}
