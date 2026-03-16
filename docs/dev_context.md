# Uni-Dash: Developer Context

## Architecture Overview
- **Frontend:** Flutter (Web, Desktop, Mobile)
- **Backend:** FastAPI (Python)
- **Database:** Supabase (PostgreSQL)
- **Edge Deployment:** Raspberry Pi (for local/edge inference and control)
- **LLM Routing:** Machine Learning module for email classification and insight extraction

## Key Modules
- **Frontend:**
  - `screens/entry/intro_screen.dart`: Entry/authentication UI
  - `screens/dashboard/`: Main dashboard and widgets
  - `theme.dart`: Theming and design tokens
- **Backend:**
  - `app/`: FastAPI app, routers, services
  - `models/`: Database models
  - `ai/`: ML/LLM integration
- **ML/LLM:**
  - `Machine_Learning_Algo/`: Dataset, inference, evaluation scripts

## Design Philosophy
- Premium, tool-like, and minimal UI
- Responsive layouts for all platforms
- Clear visual hierarchy and modular components
- Subtle, purposeful animation (no visual noise)
- Consistent spacing and grid system
- No breaking of existing API contracts

## Deployment Model
- CI/CD pipeline deploys backend to Raspberry Pi
- Frontend built for web and desktop
- Database managed via Supabase
- LLM inference can run locally or on edge

## Current Constraints
- Maintain API compatibility between frontend and backend
- No breaking changes to database schema without migration
- UI/UX changes must preserve accessibility and responsiveness

## Example Prompt for AI-DLC
> "Given this repo and dev_context.md, generate a 5-step plan to refactor the dashboard for clarity, responsiveness, and UI personalityGiven this repo and dev_context.md, generate a 5-step plan to refactor the dashboard for clarity, responsiveness, and UI personality, without breaking API contracts. Then implement steps 1 and 2."
