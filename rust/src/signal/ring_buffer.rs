//! A fixed-capacity FIFO that overwrites only when its caller explicitly permits it.

#[derive(Clone, Debug, PartialEq)]
pub struct RingBuffer<T: Copy + Default> {
    storage: Vec<T>,
    oldest: usize,
    len: usize,
}

impl<T: Copy + Default> RingBuffer<T> {
    pub fn new(capacity: usize) -> Self {
        assert!(capacity > 0, "ring buffer capacity must be positive");
        Self {
            storage: vec![T::default(); capacity],
            oldest: 0,
            len: 0,
        }
    }

    pub fn capacity(&self) -> usize {
        self.storage.len()
    }

    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Appends an item and returns the overwritten oldest item, if the buffer was full.
    pub fn push(&mut self, item: T) -> Option<T> {
        let capacity = self.capacity();
        if self.len < capacity {
            let write_index = (self.oldest + self.len) % capacity;
            self.storage[write_index] = item;
            self.len += 1;
            None
        } else {
            let overwritten = self.storage[self.oldest];
            self.storage[self.oldest] = item;
            self.oldest = (self.oldest + 1) % capacity;
            Some(overwritten)
        }
    }

    pub fn discard_oldest(&mut self, count: usize) {
        assert!(
            count <= self.len,
            "cannot discard more items than are buffered"
        );
        self.oldest = (self.oldest + count) % self.capacity();
        self.len -= count;
    }

    pub fn clear(&mut self) {
        self.oldest = 0;
        self.len = 0;
    }

    pub fn get(&self, offset_from_oldest: usize) -> Option<T> {
        (offset_from_oldest < self.len)
            .then(|| self.storage[(self.oldest + offset_from_oldest) % self.capacity()])
    }

    pub fn get_from_newest(&self, offset: usize) -> Option<T> {
        self.len
            .checked_sub(offset + 1)
            .and_then(|index| self.get(index))
    }

    pub fn copy_oldest_into(&self, output: &mut [T]) {
        assert!(output.len() <= self.len, "not enough buffered items");
        for (index, target) in output.iter_mut().enumerate() {
            *target = self
                .get(index)
                .expect("output length was checked against ring buffer length");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::RingBuffer;

    #[test]
    fn preserves_fifo_order_across_wraparound() {
        let mut buffer = RingBuffer::new(3);
        assert_eq!(buffer.push(1), None);
        assert_eq!(buffer.push(2), None);
        assert_eq!(buffer.push(3), None);
        buffer.discard_oldest(2);
        buffer.push(4);
        buffer.push(5);
        let mut actual = [0; 3];
        buffer.copy_oldest_into(&mut actual);
        assert_eq!(actual, [3, 4, 5]);
        assert_eq!(buffer.get_from_newest(0), Some(5));
        assert_eq!(buffer.get_from_newest(2), Some(3));
    }

    #[test]
    fn reports_an_overwritten_value_when_full() {
        let mut buffer = RingBuffer::new(2);
        buffer.push(1);
        buffer.push(2);
        assert_eq!(buffer.push(3), Some(1));
        let mut actual = [0; 2];
        buffer.copy_oldest_into(&mut actual);
        assert_eq!(actual, [2, 3]);
    }
}
