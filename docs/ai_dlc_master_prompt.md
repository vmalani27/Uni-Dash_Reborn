# AI-DLC Master Prompt Template

Use this template to instruct AI to plan and execute module-wide or system-wide refactors efficiently.

---

## Master Prompt Example

"You are an expert Flutter and Python developer working on the Uni-Dash project. The repository structure and system context are described in dev_context.md. Your task is to:

1. Analyze the current state of the [MODULE or FEATURE] (e.g., dashboard, auth flow, ML pipeline).
2. Propose a step-by-step implementation plan to achieve the following objectives:
   - [Objective 1: e.g., improve responsiveness]
   - [Objective 2: e.g., enhance visual hierarchy]
   - [Objective 3: e.g., modularize components]
   - [Any constraints: e.g., do not break API contracts]
3. Present the plan for review. After approval, implement each step sequentially, validating after each batch.
4. Use the design philosophy and constraints from dev_context.md as guidance.
5. Output only the code changes and explanations for each step."

---

## Usage
- Replace [MODULE or FEATURE] and objectives as needed.
- Always reference dev_context.md for system-wide context.
- Use this prompt to drive batch refactors, not micro-tweaks.
