import Testing

/// Suite tags used for plan-level inclusion and exclusion.
extension Tag {
    /// Minutes, not seconds, and CPU-saturating while it runs — which starves
    /// every timing-sensitive suite sharing the host. Excluded from the
    /// default plan; run deliberately. `PerftDeepTests` is the whole
    /// population today.
    @Tag static var slow: Self
}
