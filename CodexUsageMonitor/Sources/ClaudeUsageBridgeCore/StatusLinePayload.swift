import Foundation

/// Extracts only the `rate_limits` fields from a Claude Code statusLine payload.
///
/// Returns `nil` when `rate_limits` is absent, malformed, or has neither window,
/// so the caller leaves any previously written snapshot untouched rather than
/// overwriting it with an empty one. Mirrors the former Python `extract_snapshot`.
public func extractSnapshot(from payload: Any?, capturedAt: Int) -> RateLimitSnapshot? {
    guard let root = payload as? [String: Any],
          let rateLimits = root["rate_limits"] as? [String: Any]
    else { return nil }

    let fiveHour = window(from: rateLimits["five_hour"])
    let sevenDay = window(from: rateLimits["seven_day"])
    guard fiveHour != nil || sevenDay != nil else { return nil }

    return RateLimitSnapshot(capturedAt: capturedAt, fiveHour: fiveHour, sevenDay: sevenDay)
}

/// Decodes JSON text (as read from stdin) into a loosely-typed payload. Invalid
/// JSON yields `nil`, treated the same as a missing `rate_limits` block.
public func decodePayload(_ jsonText: String) -> Any? {
    guard let data = jsonText.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
}

private func window(from value: Any?) -> RateLimitWindow? {
    guard let dict = value as? [String: Any] else { return nil }

    // JSONSerialization surfaces JSON numbers as NSNumber; reject Bool, which is
    // also bridged as NSNumber, to match the Python type checks.
    guard let usedPercentage = number(dict["used_percentage"]),
          let resetsAtNumber = number(dict["resets_at"]),
          isInteger(dict["resets_at"])
    else { return nil }

    return RateLimitWindow(
        usedPercentage: usedPercentage.doubleValue,
        resetsAt: resetsAtNumber.intValue
    )
}

private func number(_ value: Any?) -> NSNumber? {
    guard let number = value as? NSNumber else { return nil }
    // `NSNumber` bridges Bool as a number; a boolean is never a valid percentage
    // or timestamp, so exclude it.
    if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
    return number
}

private func isInteger(_ value: Any?) -> Bool {
    guard let number = number(value) else { return false }
    // `resets_at` must be an integer epoch, not a fractional number.
    return number.doubleValue.truncatingRemainder(dividingBy: 1) == 0
}
