# Authorization flow

Telegraphica treats TDLib authorization as a resumable state machine. The UI is derived from the latest `updateAuthorizationState`; it does not assume that phone number, Telegram code, and 2FA password are the only possible steps.

## Supported states

| TDLib state | Telegraphica action |
|---|---|
| `authorizationStateWaitPhoneNumber` | Phone-number form and optional QR entry point |
| `authorizationStateWaitOtherDeviceConfirmation` | QR confirmation window; closing it cancels the pending QR attempt and restores phone login |
| `authorizationStateWaitEmailAddress` | Email-address input |
| `authorizationStateWaitEmailCode` | Email-code input, redacted destination hint, and resend action |
| `authorizationStateWaitCode` | Telegram login-code input and server-timed resend action when another delivery method exists |
| `authorizationStateWaitRegistration` | First and optional last name registration input |
| `authorizationStateWaitPassword` | Secure 2FA password input and recovery action when TDLib reports a recovery email |
| `authorizationStateReady` | Normal application UI |
| closing/closed states | Bounded client reconstruction without deleting the local account database |

The modern TDLib lane uses the current structured `emailAddressAuthenticationCode` payload. Unsupported requests are recorded by `TGTDLibCapabilities`; they do not leave the login form busy indefinitely. The OS X 10.8 fallback continues to use the states its bundled TDLib actually emits.

## Passkeys

OS X 10.8–10.13 has no compatible system WebAuthn/passkey framework for this application target. Telegraphica therefore does not attempt to collect or emulate passkey credentials. Users can authenticate with a phone number, a Telegram code and 2FA password, or approve QR login from an already authorized device. This is a deliberate runtime limitation, not a paid-feature restriction.

## Credential handling

- Passwords, Telegram codes, email codes, and recovery codes are copied only for the bounded TDLib request and are cleared from the visible field before background work starts.
- Diagnostic text records the step name, never the submitted value.
- Password entry uses `NSSecureTextField`.
- Cached authorization details contain only presentation-safe values such as code length, resend timeout, and Telegram-provided redacted email patterns.
- Closing the QR window explicitly cancels that QR attempt. Application termination shuts down the TDLib client, wakes pending request waiters, and leaves no unbounded authorization request.

## Fixture coverage

`Tests/authorization_flow_probe.m` validates every supported input state, safe extraction of resend/email presentation details, registration-name parsing, and modern email-code/resend payload helpers without using a real Telegram account.
