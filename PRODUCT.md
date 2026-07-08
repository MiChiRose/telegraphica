# Product

## Register

product

## Users

Telegraphica is built for a user who deliberately keeps an Intel Mac on OS X
10.9 Mavericks, with OS X 10.13 High Sierra as a secondary compatibility target.
The user wants a practical Telegram client that works on older Mac hardware
without requiring a system upgrade.

## Product Purpose

Telegraphica exists to prove and then ship a small unofficial Telegram desktop
client for legacy macOS. Success means the app can authorize through TDLib, keep
the local session safe, list chats, read recent messages, send plain text, and
grow into a dependable daily-use interface without modern macOS-only APIs.

## Brand Personality

Quiet, tactile, resilient. The app should feel like a native old-Mac utility:
calm, familiar, slightly physical, and focused on the conversation rather than
on decorative novelty.

## Anti-references

Do not imitate official Telegram branding, logos, or assets. Avoid glossy modern
web-app styling, flat SaaS dashboards, translucent/glass effects that require
newer macOS conventions, oversized marketing layouts, and decorative UI that
would feel foreign on Mavericks.

## Design Principles

- Native before novel: use familiar AppKit controls and platform behavior.
- Tactile restraint: skeuomorphic depth is welcome when it clarifies surfaces,
  hierarchy, and affordances.
- Core reliability first: every visual change must preserve TDLib auth, reading,
  sending, logging redaction, and legacy build compatibility.
- Private by default: local chat data can be visible in the UI, but diagnostics
  and archives must stay redacted.
- Progressive client shell: evolve from the spike into a real chat client one
  stable workflow at a time.

## Accessibility & Inclusion

Prefer system fonts, strong contrast, keyboard-reachable standard controls, and
clear focus behavior. Do not depend on animation, translucency, or color alone
to convey state.
