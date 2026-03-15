class MemoryCacheEntry<T> {
  final T value;
  final DateTime timestamp;

  const MemoryCacheEntry(this.value, this.timestamp);

  factory MemoryCacheEntry.now(T value) {
    return MemoryCacheEntry<T>(value, DateTime.now());
  }

  bool isFresh(Duration ttl) {
    return DateTime.now().difference(timestamp) <= ttl;
  }
}
