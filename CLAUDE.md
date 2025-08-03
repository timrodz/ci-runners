# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GitHub Actions Monitor** - A real-time monitoring dashboard for GitHub Actions workflows using Phoenix LiveView.

### MVP Features
- Webhook endpoint with HMAC-SHA256 signature verification for GitHub webhooks
- Database storage for Repository, WorkflowRun, and WorkflowJob entities
- Real-time LiveView dashboard displaying workflow runs and jobs
- PubSub integration for live updates
- Test-driven development approach with comprehensive coverage

### Development Setup

#### Prerequisites
- SMEE tunnel configured and forwarding GitHub webhooks to port 4000
- PostgreSQL database (via Docker Compose)
- GitHub webhook secret configured in environment variables

#### SMEE Tunnel
The application uses SMEE for webhook forwarding during development. The tunnel should be configured to forward GitHub webhook events to `localhost:4000/webhooks/github`.

## Development Commands

### Setup and Dependencies
- `mix setup` - Install dependencies, setup database, and build assets (includes deps.get, ecto.setup, assets.setup, assets.build)
- `mix deps.get` - Install Elixir dependencies

### Database
- `mix ecto.setup` - Create database, run migrations, and seed data
- `mix ecto.create` - Create the database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.reset` - Drop and recreate database with fresh data
- `mix ecto.drop` - Drop the database

### Development Server
- `mix phx.server` - Start the Phoenix server (available at localhost:4000)
- `iex -S mix phx.server` - Start server in interactive Elixir shell

### Testing
- `mix test` - Run all tests (automatically creates test database and runs migrations)
- `mix test test/path/to/specific_test.exs` - Run a specific test file
- `mix test --cover` - Run tests with coverage report

### Assets
- `mix assets.setup` - Install Tailwind and esbuild if missing
- `mix assets.build` - Build assets for development
- `mix assets.deploy` - Build and minify assets for production

### Docker
- `docker-compose up db` - Start PostgreSQL database container

## Architecture Overview

This is a Phoenix 1.8 web application implementing a GitHub Actions monitoring system:

### Core Stack
- **Phoenix Framework**: Web framework with LiveView support for real-time UI
- **Ecto**: Database ORM with PostgreSQL adapter
- **Phoenix PubSub**: Real-time messaging for live updates
- **Bandit**: HTTP server adapter
- **Tailwind CSS**: Utility-first CSS framework
- **esbuild**: JavaScript bundler

### Data Models
- **Repository**: GitHub repositories with webhook configuration
- **WorkflowRun**: Individual workflow executions with status tracking
- **WorkflowJob**: Jobs within workflow runs with runner information

### Application Structure
- `lib/ci_runners/` - Core business logic and contexts
  - `application.ex` - OTP application supervisor tree with PubSub
  - `repo.ex` - Ecto repository for database access
  - `github/` - GitHub integration modules
    - `webhook_verifier.ex` - HMAC-SHA256 signature verification
    - `webhook_handler.ex` - GitHub event processing logic
- `lib/ci_runners_web/` - Web layer (controllers, views, templates)
  - `endpoint.ex` - Phoenix endpoint configuration
  - `router.ex` - URL routing and pipelines
  - `controllers/` - HTTP request handlers including webhook controller
  - `live/` - LiveView modules for real-time dashboard
  - `components/` - Reusable UI components and layouts
- `config/` - Environment-specific configuration
- `priv/repo/migrations/` - Database schema migrations
- `test/` - Test files mirroring lib/ structure

### Key Features
- **Real-time Dashboard**: LiveView-based dashboard with automatic updates
- **Webhook Processing**: Secure GitHub webhook endpoint with signature verification
- **Live Updates**: PubSub integration for real-time workflow status changes
- **Comprehensive Testing**: Unit, integration, and end-to-end test coverage
- LiveDashboard available at `/dev/dashboard` in development
- Swoosh mailbox preview at `/dev/mailbox` in development
- Telemetry integration for monitoring
- CSRF protection and secure headers
- Database connection sandboxing for tests

### GitHub Integration
- **Webhook Endpoint**: `/webhooks/github` for receiving GitHub events
- **Event Types**: Handles `workflow_run` and `workflow_job` events
- **Security**: HMAC-SHA256 signature verification for all incoming webhooks
- **Data Flow**: GitHub → Webhook → Database → PubSub → LiveView → UI

### Database
- PostgreSQL database (available via Docker Compose)
- Three main entities: Repository, WorkflowRun, WorkflowJob
- Proper associations and foreign key constraints
- Ecto migrations for schema changes
- Test database automatically managed during test runs

## Environment Configuration

Required environment variables:
- `GITHUB_WEBHOOK_SECRET` - Secret for verifying GitHub webhook signatures

## Development Approach

This project follows a **test-driven development (TDD)** approach with:
- Comprehensive unit tests for all modules
- Integration tests for webhook processing
- LiveView tests for real-time functionality
- End-to-end tests for complete workflow
- All tests must pass before implementation is considered complete

## Implementation Progress

See `TASKS.md` for detailed task breakdown and current progress. The MVP is being implemented in 9 structured tasks with clear dependencies and comprehensive test coverage.