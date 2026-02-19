import Foundation

struct RingBuffer<Element>: RandomAccessCollection, Sendable where Element: Sendable {
    private var storage: [Element]
    private var head: Int = 0
    private var count_: Int = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count_ }
    var count: Int { count_ }
    var isEmpty: Bool { count_ == 0 }

    subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count_)
        let realIndex = (head + index) % storage.count
        return storage[realIndex]
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
            count_ = storage.count
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
        count_ = 0
    }

    var last: Element? {
        guard !isEmpty else { return nil }
        let idx = storage.count < capacity
            ? storage.count - 1
            : (head + count_ - 1) % capacity
        return storage[idx]
    }

    func toArray() -> [Element] {
        Array(self)
    }
}
