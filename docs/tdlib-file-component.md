# TDLib file component

Download, cancellation and local-cache deletion requests live in
`TGTDLibClient+Files`. The component reuses the main client's transport and
file-response parser, while download managers and media surfaces depend only on
the focused category API.

The account-free fixture probe locks the request types, priority, completion
path validation, cancellation semantics and invalid-identifier rejection.
