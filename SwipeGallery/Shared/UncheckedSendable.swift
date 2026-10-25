import Foundation

/// Trasporta fra thread un valore che il framework non dichiara `Sendable`
/// (per esempio `UIImage` o `AVPlayerItem` restituiti da PhotoKit) quando lo si
/// passa a un solo destinatario senza condividerlo.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
