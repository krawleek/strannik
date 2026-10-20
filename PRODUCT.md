# Странник

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Russian-speaking children aged 7–11 learning financial concepts through an existing game with a pet, stages, lessons and earned rewards.

## Product Purpose

Teach financial knowledge through interactive fictional scenarios, choices and explanations. Financial-safety lessons should help children recognize suspicious calls and messages, end suspicious conversations and tell a trusted adult, and avoid sharing financial information.

## Operating Context

The existing app uses Flutter/Dart, works offline and persists game and lesson state in SQLite. Learning, economy and progression use the existing services, repositories and transaction system; no backend is required for the Stage 3 lessons.

## Capabilities and Constraints

- Stage 3 is `homePlanet`. Its financial-safety topic is `home_planet_safety`, titled «Финансовая безопасность», containing the independent tasks «Секретный звонок» (`home_planet_safety_call`) and «Поздравляем, ты выиграл!» (`home_planet_safety_email`).
- Preserve existing Stage 1/Stage 2 task identities and behavior. Real stage progression belongs to permanent pet state; demo stage overrides must not change permanent progression.
- Each safety task grants the current canonical +40 фир and +15 XP once through the existing reward system. Replays and repeated callbacks must not duplicate rewards. Topic completion requires both published investigations; the separately approved finale grants +500 фир and +30 XP once. The undefined «Мама, это ты?» concept remains a non-playable card outside this required list.
- Persist meaningful lesson progress, completion and reward state. Incorrect choices receive explanations and permit continued learning.
- Calls, emails, prize pages and payment requests are fictional in-app learning objects. They must not invoke real telephone, browser, email or payment services. Fictional prizes and fees must not affect the wallet.
- Mock card fields are display-only. Never collect, focus editable fields for, store, log or transmit actual payment-card details.

## Brand Commitments

Preserve the established Russian-language «Странник» identity, original illustrations and incumbent visual system. The Stage 3 design authority is the supplied [Figma Stage 3 tasks section](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=40000217-20793), used within the existing app's tokens and shared components. This extension does not establish a replacement visual world or authorize global design changes.

## Evidence on Hand

The task brief supplies the audience, platform, behavior and child-safety requirements. Existing implementation authorities include `lib/presentation/foundation/app_tokens.dart`, shared presentation components, `lib/content/seed/development.json` and the domain services. Stage 3 implementation details, actual validation and unresolved Figma copy discrepancies are recorded in `STAGE3_IMPLEMENTATION.md`; artwork origins are recorded in `assets/learning/SAFETY_ASSETS.md`.

## Product Principles

- Teach through choices and explanations with recovery from mistakes.
- Keep fictional fraud scenarios isolated from real financial data, communications and balances.
- Preserve progress and grant each earned reward once.
- Extend existing curriculum, progression and visual authority without silently replacing established behavior.

## Accessibility & Inclusion

Use Russian copy suitable for children aged 7–11. Support the 360×800 dp reference and different Android heights, respect system insets, and keep actions reachable through scrolling when content exceeds the viewport.
