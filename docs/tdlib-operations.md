# Cancellable TDLib operations

`TGTDLibOperation` is the shared primitive for bounded asynchronous TDLib reads.
It provides a unique operation identifier, cancellation, a bounded timeout,
generation-token validation, exactly-once completion, stale-result suppression,
and main-thread delivery.

Automatic retry is disabled by default. It is limited to one attempt, requires
both an explicitly idempotent operation and an error marked with
`TGTDLibOperationRetryableErrorKey`. Message send, edit, delete, payment, and
other destructive operations must never opt into automatic retry.

Owners retain active operations and cancel them when their window/controller is
closed. Completion removes the operation from the owner's bounded collection.
Server-provided reaction discovery is the first migrated consumer: it keeps at
most one read operation per message and a bounded 80-entry result cache.
No request or result body is logged by this component; callers may log only the
operation ID, duration, capability name, and normalized error category.
