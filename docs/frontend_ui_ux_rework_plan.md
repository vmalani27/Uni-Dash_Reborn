# Uni-Dash Frontend UI/UX Rework Plan

## Overview
This document outlines a comprehensive plan to transform the Uni-Dash frontend from a mobile-centric app to a modern, responsive web application. The goal is to improve user understanding, usability, and the ability to express academic context using the intelligence already present in the backend.

---

## 1. Entry Point & Navigation
- Refactor AuthGate for web-friendly navigation (URL routing, not just push).
- Add persistent sidebar or top navigation for main sections (Dashboard, Deadlines, Assignments, Profile, etc.).
- Use web-appropriate loading indicators with branding/context.
- Ensure navigation is keyboard accessible and works with browser navigation.

## 2. Theming, Colors, and Dark/Light Mode
- Audit all color usage for contrast and accessibility.
- Ensure both dark and light themes are fully supported and tested.
- Use Material 3 color schemes and surface/elevation tokens.
- Add a theme toggle for user control.

## 3. Layout & Responsiveness
- Implement responsive layouts using LayoutBuilder, MediaQuery, or responsive packages.
- Use max-width containers for main content on desktop.
- Add breakpoints for sidebar vs. topbar navigation.
- Ensure dialogs, modals, and overlays are centered and sized for web.

## 4. Dashboard & Information Architecture
- Redesign dashboard to show:
  - Upcoming deadlines (with urgency color/indicator)
  - Assignments grouped by course
  - Exams and important events
  - Announcements and opportunities
- Use cards/list tiles with structured fields: course, instructor, due date, urgency, source.
- Make emails supporting evidence, not the main object.

## 5. Category Navigation & Filtering
- Replace vertical stacks with tabs or a sidebar filter.
- Allow users to quickly switch between categories.
- Add search and sort options for power users.

## 6. Animations & Transitions
- Use subtle, fast transitions for navigation and state changes.
- Avoid overuse of hero animations or long transitions.
- Ensure all animations are performant on web.

## 7. Accessibility & Usability
- Audit for accessibility (color, keyboard, screen reader).
- Add focus indicators and skip links.
- Use semantic widgets and roles.

## 8. Data Mapping & Backend Integration
- Map backend fields to UI components:
  - deadline_iso → Due date
  - normalized_topic → Category
  - academic_score → Importance
  - ai_summary → Summary
  - ai_label_urgency → Urgency indicator
- Show missing fields in the appropriate context (e.g., course/instructor on assignment cards).

## 9. To Remove
- Remove mobile-only navigation patterns (e.g., back button in AppBar for web).
- Remove redundant or duplicate screens.
- Remove unused assets or code from the mobile era.

## 10. To Change
- Change all navigation to use named routes and URL paths.
- Change all color and theme usage to be dynamic and accessible.
- Change dashboard to be context-first, not message-first.

## 11. To Add
- Add dashboard overview with actionable insights.
- Add responsive layouts and breakpoints.
- Add structured cards for assignments, exams, etc.
- Add sidebar or tab navigation.
- Add theme toggle and accessibility features.

---

This plan is based on current backend capabilities, upcoming work, and best practices for responsive web apps. Each section can be broken down into actionable tasks and wireframes as needed.