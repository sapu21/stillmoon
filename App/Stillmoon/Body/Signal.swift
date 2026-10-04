import Foundation

/// Small, dependency-free signal helpers shared by the pulse and breathing analyzers.
enum Signal {
    /// Centered moving average; the window shrinks at the edges.
    static func movingAverage(_ x: [Double], window: Int) -> [Double] {
        guard window > 1, !x.isEmpty else { return x }
        var prefix = [0.0]
        prefix.reserveCapacity(x.count + 1)
        for v in x { prefix.append(prefix.last! + v) }
        let half = window / 2
        return x.indices.map { i in
            let lo = max(0, i - half), hi = min(x.count, i + half + 1)
            return (prefix[hi] - prefix[lo]) / Double(hi - lo)
        }
    }

    /// Removes slow drift (finger pressure, room noise) by subtracting a long moving average.
    static func detrend(_ x: [Double], window: Int) -> [Double] {
        zip(x, movingAverage(x, window: window)).map { $0 - $1 }
    }

    static func mean(_ x: [Double]) -> Double { x.isEmpty ? 0 : x.reduce(0, +) / Double(x.count) }

    static func standardDeviation(_ x: [Double]) -> Double {
        let m = mean(x)
        return x.isEmpty ? 0 : sqrt(x.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(x.count))
    }

    static func median(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        let s = x.sorted()
        return s.count.isMultiple(of: 2) ? (s[s.count / 2 - 1] + s[s.count / 2]) / 2 : s[s.count / 2]
    }

    /// Normalized autocorrelation at `lag` (1 = perfectly periodic at that lag).
    static func autocorrelation(_ x: [Double], lag: Int) -> Double {
        guard lag > 0, lag < x.count else { return 0 }
        let m = mean(x)
        var num = 0.0, den = 0.0
        for i in x.indices {
            let d = x[i] - m
            den += d * d
            if i + lag < x.count { num += d * (x[i + lag] - m) }
        }
        return den > 0 ? num / den : 0
    }

    /// Local maxima above `threshold`, at least `minDistance` samples apart (the higher one wins),
    /// refined to sub-sample positions with a parabola through each peak and its neighbours.
    static func peaks(_ y: [Double], minDistance: Int, threshold: Double) -> [Double] {
        guard y.count > 2 else { return [] }
        var picked: [Int] = []
        for i in 1..<(y.count - 1) where y[i] > threshold && y[i] > y[i - 1] && y[i] >= y[i + 1] {
            if let last = picked.last, i - last < minDistance {
                if y[i] > y[last] { picked[picked.count - 1] = i }
            } else {
                picked.append(i)
            }
        }
        return picked.map { i in
            let denom = y[i - 1] - 2 * y[i] + y[i + 1]
            let offset = denom == 0 ? 0 : 0.5 * (y[i - 1] - y[i + 1]) / denom
            return Double(i) + max(-0.5, min(0.5, offset))
        }
    }
}
