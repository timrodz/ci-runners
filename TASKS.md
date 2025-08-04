# TASKS.md - GitHub Actions Monitor MVP

This document breaks down the MVP implementation into manageable tasks with clear dependencies and test-driven development approach.

## Phase 1: MVP Core Features
- ✅ Webhook endpoint with signature verification
- ✅ Database storage for Repository, WorkflowRun, WorkflowJob
- ✅ Basic LiveView dashboard displaying workflow runs
- ✅ Real-time updates via PubSub + LiveView
- ✅ Comprehensive test coverage

## Task Breakdown

### Foundation Tasks (No Dependencies)

#### TASK-001: Database Schema Setup ✅ COMPLETED
**Priority:** High | **Estimated Time:** 2-3 hours
- [x] Create Repository Ecto schema with fields: id, owner, name, github_id, timestamps (updated to use owner/name instead of full_name)
- [x] Create WorkflowRun Ecto schema with fields: id, github_id, name, status, conclusion, workflow_id, head_branch, head_sha, run_number, started_at, completed_at, repository_id, timestamps
- [x] Create WorkflowJob Ecto schema with fields: id, github_id, name, status, conclusion, runner_name, runner_group_name, started_at, completed_at, workflow_run_id, timestamps
- [x] Add proper Ecto associations (Repository has_many WorkflowRuns, WorkflowRun belongs_to Repository and has_many WorkflowJobs, WorkflowJob belongs_to WorkflowRun)
- [x] Create database migrations with indexes, unique constraints, and foreign key constraints
- [x] Write comprehensive schema tests for validations and associations (31 tests passing)

**Dependencies:** None
**Test Coverage:** Schema validations, associations, database constraints, unique constraints
**Completed:** Repository schema uses owner/name structure (e.g. "timrodz/racing-leaderboards"), all schemas have proper associations, comprehensive test coverage with edge cases

#### TASK-002: Webhook Signature Verification Module ✅ COMPLETED
**Priority:** High | **Estimated Time:** 1-2 hours
- [x] Create `CiRunners.Github.WebhookVerifier` module
- [x] Implement HMAC-SHA256 signature verification with constant-time comparison
- [x] Handle X-Hub-Signature-256 header parsing
- [x] Add configuration for webhook secret via environment variable
- [x] Write unit tests for signature verification (valid/invalid signatures, malformed headers)

**Dependencies:** None
**Test Coverage:** Valid signatures, invalid signatures, missing headers, malformed data
**Completed:** WebhookVerifier module with HMAC-SHA256 verification, constant-time comparison to prevent timing attacks, X-Hub-Signature-256 header parsing, GH_REPO_SECRET environment variable support, comprehensive test coverage (28 tests passing)

### Core Webhook Processing (Depends on Foundation)

#### TASK-003: Webhook Controller and Routes ✅ COMPLETED
**Priority:** High | **Estimated Time:** 2-3 hours
- [x] Add POST /webhooks/github route
- [x] Create `CiRunnersWeb.WebhookController` with receive action
- [x] Implement request body reading and signature verification
- [x] Add proper error responses (401 for invalid signature, 400 for malformed payload)
- [x] Extract GitHub event type from X-GitHub-Event header
- [x] Route to appropriate event handler based on event type
- [x] Write controller tests with mock GitHub payloads

**Dependencies:** TASK-002
**Test Coverage:** Valid requests, invalid signatures, malformed payloads, unknown event types
**Completed:** Webhook controller at `/api/webhooks/github` with HMAC-SHA256 signature verification, event type routing for workflow_run/workflow_job events, comprehensive error handling (401/400/500), complete test coverage (10 tests) with mock GitHub payloads, object-to-string payload transformation in WebhookVerifier

#### TASK-004: Workflow Event Processing Logic ✅ COMPLETED
**Priority:** High | **Estimated Time:** 3-4 hours
- [x] Create `CiRunners.Github.WebhookHandler` module
- [x] Implement `handle_workflow_run/1` function to process workflow_run events
- [x] Implement `handle_workflow_job/1` function to process workflow_job events
- [x] Add repository creation/update logic with upsert behavior
- [x] Add workflow_run creation/update logic with proper status transitions
- [x] Add workflow_job creation/update logic with association to workflow_run
- [x] Write comprehensive unit tests with sample GitHub payloads

**Dependencies:** TASK-001, TASK-003
**Test Coverage:** New repositories, existing repositories, workflow status transitions, job associations
**Completed:** WebhookHandler module with comprehensive event processing, repository/workflow_run/workflow_job upsert logic, robust error handling and validation, updated database schema to use bigint for GitHub IDs, complete test coverage (23 tests) including edge cases and error scenarios

### Real-time Infrastructure (Depends on Core Processing)

#### TASK-005: PubSub Integration
**Priority:** High | **Estimated Time:** 1-2 hours
- [ ] Configure Phoenix PubSub in application.ex
- [ ] Add PubSub broadcasting to webhook handler after database updates
- [ ] Define message formats for workflow_run_updated and workflow_job_updated
- [ ] Create helper module for PubSub topic management
- [ ] Write tests for PubSub message broadcasting

**Dependencies:** TASK-004
**Test Coverage:** Message broadcasting, topic subscription, message formats

### LiveView Implementation (Depends on Real-time Infrastructure)

#### TASK-006: Basic Dashboard LiveView
**Priority:** High | **Estimated Time:** 3-4 hours
- [ ] Create `CiRunnersWeb.DashboardLive` LiveView module
- [ ] Implement mount/3 with PubSub subscription to workflow updates
- [ ] Load recent workflow runs with preloaded associations (repository, jobs)
- [ ] Implement handle_info/2 for workflow_run_updated and workflow_job_updated messages
- [ ] Create basic HTML template displaying workflow runs in chronological order
- [ ] Add route for dashboard at "/"
- [ ] Write LiveView tests for mount behavior and real-time updates

**Dependencies:** TASK-005
**Test Coverage:** LiveView mounting, PubSub message handling, state updates

#### TASK-007: UI Components and Styling
**Priority:** Medium | **Estimated Time:** 2-3 hours
- [ ] Create WorkflowRunCard component displaying run name, number, status, branch
- [ ] Create WorkflowJobItem component displaying job name, status, runner info
- [ ] Create StatusBadge component with color-coded status indicators
- [ ] Implement responsive TailwindCSS styling
- [ ] Add loading states and connection status indicator
- [ ] Add proper styling for different statuses (queued: gray, in_progress: blue, success: green, failure: red)
- [ ] Write component tests for rendering and styling

**Dependencies:** TASK-006
**Test Coverage:** Component rendering, status styling, responsive behavior

### Integration and End-to-End (Depends on All Previous)

#### TASK-008: Integration Testing
**Priority:** High | **Estimated Time:** 2-3 hours
- [ ] Create end-to-end test for complete webhook-to-UI flow
- [ ] Test real GitHub webhook payloads (workflow_run and workflow_job events)
- [ ] Test multiple LiveView clients receiving simultaneous updates
- [ ] Test database persistence and data integrity
- [ ] Test error handling and recovery scenarios
- [ ] Verify PubSub message delivery and LiveView updates

**Dependencies:** TASK-007
**Test Coverage:** Complete flow integration, multi-client updates, error scenarios

#### TASK-009: Environment Configuration and Documentation
**Priority:** Medium | **Estimated Time:** 1-2 hours
- [ ] Add required environment variables to config (GITHUB_WEBHOOK_SECRET)
- [ ] Update CLAUDE.md with webhook setup instructions
- [ ] Add sample .env file with configuration examples
- [ ] Document webhook endpoint URL for GitHub configuration
- [ ] Add troubleshooting guide for common issues
- [ ] Verify all tests pass and application starts successfully

**Dependencies:** TASK-008
**Test Coverage:** Configuration validation, startup verification

## Task Dependencies Graph

```
TASK-001 (Database Schema)
    ↓
TASK-003 (Webhook Controller) ← TASK-002 (Signature Verification)
    ↓
TASK-004 (Event Processing)
    ↓
TASK-005 (PubSub Integration)
    ↓
TASK-006 (Dashboard LiveView)
    ↓
TASK-007 (UI Components)
    ↓
TASK-008 (Integration Testing)
    ↓
TASK-009 (Configuration & Docs)
```

## Definition of Done for MVP
- [ ] All webhook endpoints accept and process GitHub events correctly
- [ ] Database stores all three entity types with proper relationships
- [ ] LiveView dashboard displays workflow runs in real-time
- [ ] All tests pass (unit, integration, end-to-end)
- [ ] Code is maintainable with clear module boundaries
- [ ] SMEE webhook forwarding works end-to-end
- [ ] Application can be started with `mix phx.server` and receives live GitHub events

## Testing Strategy Summary
- **Unit Tests:** Individual modules and functions
- **Controller Tests:** HTTP requests and responses
- **LiveView Tests:** Mount behavior and real-time updates
- **Integration Tests:** Complete webhook-to-UI flow
- **End-to-End Tests:** Real GitHub webhook processing

Each task should be completed with full test coverage before moving to dependent tasks.