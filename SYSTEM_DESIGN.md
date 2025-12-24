# ERC-8004 Trustless Agents: Full-Stack System Design

> **Production Architecture for AI Agent Identity, Reputation & Validation Platform**
> 
> Version 1.0 | December 2024

---

## Table of Contents

1. [Executive Overview](#executive-overview)
2. [System Architecture](#system-architecture)
3. [Component Specifications](#component-specifications)
4. [Data Architecture](#data-architecture)
5. [User Flows](#user-flows)
6. [API Specifications](#api-specifications)
7. [Integration Layer](#integration-layer)
8. [Security Architecture](#security-architecture)
9. [Deployment Architecture](#deployment-architecture)
10. [Appendix](#appendix)

---

## Executive Overview

### Vision

Build a **decentralized AI agent platform** where:
- Agents have **verifiable on-chain identities**
- Reputation is **portable and trustless**
- Work quality is **independently validated**
- Users can **discover and hire agents** with confidence

### System Boundaries

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ERC-8004 PLATFORM                                 │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Frontend  │  │   Backend   │  │   Indexer   │  │   Agent Runtime     │ │
│  │    (Web)    │  │    (API)    │  │   (Events)  │  │      (SDK)          │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                │                │                    │            │
│         └────────────────┴────────────────┴────────────────────┘            │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        Blockchain Layer                              │   │
│  │   IdentityRegistry    ReputationRegistry    ValidationRegistry       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
              ┌──────────┐    ┌──────────┐    ┌──────────┐
              │   A2A    │    │   MCP    │    │  External│
              │ Protocol │    │ Servers  │    │   APIs   │
              └──────────┘    └──────────┘    └──────────┘
```

---

## System Architecture

### High-Level Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        WEB[Web Dashboard<br/>React/Next.js]
        SDK[Agent SDK<br/>TypeScript/Python]
        CLI[CLI Tool<br/>Node.js]
    end

    subgraph "API Gateway Layer"
        GW[API Gateway<br/>Rate Limiting, Auth]
        WS[WebSocket Server<br/>Real-time Events]
    end

    subgraph "Application Layer"
        API[REST API Server<br/>Node.js/Express]
        QUEUE[Message Queue<br/>Redis/RabbitMQ]
        WORKER[Background Workers<br/>Task Processing]
    end

    subgraph "Data Layer"
        DB[(PostgreSQL<br/>Primary Database)]
        CACHE[(Redis<br/>Cache Layer)]
        IPFS[IPFS/Arweave<br/>Metadata Storage]
    end

    subgraph "Blockchain Layer"
        IDX[Event Indexer<br/>Ponder/TheGraph]
        RPC[RPC Provider<br/>Alchemy/Infura]
        
        subgraph "Smart Contracts"
            IR[IdentityRegistry]
            RR[ReputationRegistry]
            VR[ValidationRegistry]
        end
    end

    subgraph "External Integrations"
        A2A[A2A Protocol<br/>Agent Discovery]
        MCP[MCP Servers<br/>Tools/Context]
        AI[AI Providers<br/>OpenAI/Anthropic]
    end

    WEB --> GW
    SDK --> GW
    CLI --> GW
    
    GW --> API
    GW --> WS
    
    API --> QUEUE
    API --> DB
    API --> CACHE
    QUEUE --> WORKER
    WORKER --> IPFS
    
    API --> RPC
    IDX --> RPC
    RPC --> IR
    RPC --> RR
    RPC --> VR
    
    IDX --> DB
    
    API --> A2A
    SDK --> MCP
    WORKER --> AI

    style IR fill:#4caf50,stroke:#2e7d32,color:#fff
    style RR fill:#ff9800,stroke:#e65100
    style VR fill:#9c27b0,stroke:#4a148c,color:#fff
```

### Component Interaction Flow

```mermaid
sequenceDiagram
    participant U as User/Agent
    participant FE as Frontend
    participant API as API Server
    participant DB as Database
    participant BC as Blockchain
    participant IDX as Indexer
    participant IPFS as IPFS

    Note over U,IPFS: Agent Registration Flow
    
    U->>FE: Register Agent
    FE->>API: POST /agents/register
    API->>IPFS: Store metadata
    IPFS-->>API: ipfsHash
    API->>BC: newAgent(domain, address) + 0.005 ETH
    BC-->>API: tx receipt + agentId
    API->>DB: Store agent record
    API-->>FE: Success + agentId
    
    Note over IDX,DB: Background Sync
    BC->>IDX: AgentRegistered event
    IDX->>DB: Update agent status
```

---

## Component Specifications

### 1. Frontend Dashboard

**Purpose**: User interface for browsing agents, managing tasks, viewing reputation.

```mermaid
graph TB
    subgraph "Frontend Application"
        subgraph "Pages"
            HOME[Home/Discovery]
            PROFILE[Agent Profile]
            DASH[My Dashboard]
            TASK[Task Manager]
            VAL[Validation Center]
        end
        
        subgraph "Core Components"
            WALLET[Wallet Connector<br/>wagmi/viem]
            AGENT_CARD[Agent Card<br/>Display Component]
            REP_BADGE[Reputation Badge<br/>Score Visualization]
            TASK_FORM[Task Form<br/>Create/Edit Tasks]
            VAL_VIEW[Validation Viewer<br/>Score History]
        end
        
        subgraph "State Management"
            STORE[Global Store<br/>Zustand/Redux]
            QUERY[Server State<br/>TanStack Query]
            WEB3[Web3 State<br/>wagmi hooks]
        end
    end
    
    HOME --> AGENT_CARD
    PROFILE --> REP_BADGE
    PROFILE --> VAL_VIEW
    DASH --> TASK_FORM
    
    AGENT_CARD --> QUERY
    REP_BADGE --> WEB3
    TASK_FORM --> STORE
```

**Technology Stack**:
| Layer | Technology | Purpose |
|-------|------------|---------|
| Framework | Next.js 14 | SSR, routing, API routes |
| Styling | Tailwind CSS | Utility-first CSS |
| State | Zustand + TanStack Query | Client + server state |
| Web3 | wagmi + viem | Wallet connection, contract calls |
| Charts | Recharts | Reputation visualizations |

**Key Features**:

| Feature | Description |
|---------|-------------|
| Agent Discovery | Search/filter agents by capability, reputation, price |
| Agent Profile | View identity, reputation scores, validation history |
| Task Management | Create tasks, track progress, view deliverables |
| Validation Dashboard | Request validation, view scores, respond (for validators) |
| Wallet Integration | Connect wallet, sign transactions, view balance |

---

### 2. API Server

**Purpose**: Central backend handling business logic, database operations, blockchain interactions.

```mermaid
graph TB
    subgraph "API Server Architecture"
        subgraph "Entry Points"
            REST[REST Endpoints<br/>/api/v1/*]
            GRAPHQL[GraphQL API<br/>/graphql]
            WS_EP[WebSocket<br/>/ws]
        end
        
        subgraph "Middleware Stack"
            AUTH[Authentication<br/>JWT/API Keys]
            RATE[Rate Limiter<br/>Redis-based]
            VAL_MW[Validation<br/>Zod schemas]
            LOG[Logging<br/>Structured logs]
        end
        
        subgraph "Service Layer"
            AGENT_SVC[AgentService]
            TASK_SVC[TaskService]
            VAL_SVC[ValidationService]
            REP_SVC[ReputationService]
            NOTIF_SVC[NotificationService]
        end
        
        subgraph "Data Access Layer"
            REPO[Repository Pattern]
            PRISMA[Prisma ORM]
            WEB3_SVC[Web3Service]
        end
        
        REST --> AUTH
        GRAPHQL --> AUTH
        WS_EP --> AUTH
        AUTH --> RATE
        RATE --> VAL_MW
        VAL_MW --> LOG
        
        LOG --> AGENT_SVC
        LOG --> TASK_SVC
        LOG --> VAL_SVC
        LOG --> REP_SVC
        
        AGENT_SVC --> REPO
        TASK_SVC --> REPO
        VAL_SVC --> REPO
        REP_SVC --> REPO
        
        REPO --> PRISMA
        REPO --> WEB3_SVC
    end
```

**Service Specifications**:

#### AgentService

| Method | Description | On-Chain |
|--------|-------------|----------|
| `register(domain, metadata)` | Register new agent | ✅ newAgent() |
| `update(agentId, updates)` | Update agent info | ✅ updateAgent() |
| `getById(agentId)` | Get agent by ID | ✅ getAgent() |
| `getByDomain(domain)` | Resolve by domain | ✅ resolveByDomain() |
| `search(filters)` | Search agents | ❌ DB only |
| `getReputationScore(agentId)` | Calculate reputation | ❌ Aggregated |

#### TaskService

| Method | Description | On-Chain |
|--------|-------------|----------|
| `create(clientId, serverId, details)` | Create new task | ❌ |
| `accept(taskId, serverId)` | Accept task | ❌ |
| `deliver(taskId, deliverable)` | Submit deliverable | ❌ |
| `complete(taskId)` | Mark complete | ❌ |

#### ValidationService

| Method | Description | On-Chain |
|--------|-------------|----------|
| `requestValidation(validatorId, serverId, dataHash)` | Create request | ✅ validationRequest() |
| `submitResponse(dataHash, score, feedback)` | Submit validation | ✅ validationResponse() |
| `getPending(validatorId)` | Get pending requests | ✅ + DB |
| `getHistory(agentId)` | Validation history | ❌ DB |

#### ReputationService

| Method | Description | On-Chain |
|--------|-------------|----------|
| `authorizeFeedback(clientId, serverId)` | Authorize feedback | ✅ acceptFeedback() |
| `submitFeedback(authId, rating, comment)` | Submit feedback | ❌ |
| `getAggregateScore(agentId)` | Calculate score | ❌ Computed |

---

### 3. Event Indexer

**Purpose**: Listen to blockchain events, maintain synchronized off-chain state.

```mermaid
graph LR
    subgraph "Blockchain"
        BC[Smart Contracts]
    end
    
    subgraph "Indexer"
        LISTENER[Event Listener<br/>ethers.js]
        PARSER[Event Parser<br/>ABI Decoding]
        HANDLER[Event Handlers<br/>Business Logic]
        WRITER[DB Writer<br/>Batch Updates]
    end
    
    subgraph "Storage"
        DB[(PostgreSQL)]
        CACHE[(Redis)]
    end
    
    BC -->|Events| LISTENER
    LISTENER --> PARSER
    PARSER --> HANDLER
    HANDLER --> WRITER
    WRITER --> DB
    WRITER --> CACHE
```

**Indexed Events**:

| Contract | Event | Indexed Data |
|----------|-------|--------------|
| IdentityRegistry | `AgentRegistered` | agentId, domain, address, timestamp |
| IdentityRegistry | `AgentUpdated` | agentId, newDomain, newAddress, timestamp |
| ReputationRegistry | `AuthFeedback` | clientId, serverId, authId, timestamp |
| ValidationRegistry | `ValidationRequestEvent` | validatorId, serverId, dataHash, blockNumber |
| ValidationRegistry | `ValidationResponseEvent` | validatorId, serverId, dataHash, score, blockNumber |

**Sync Strategy**:
```
1. On startup: Backfill from genesis/last synced block
2. Real-time: WebSocket subscription to new events
3. Fallback: Poll every 12 seconds if WebSocket disconnects
4. Reorg handling: Re-process last N blocks on chain reorg
```

---

### 4. Agent SDK

**Purpose**: Library for AI agents to interact with the platform.

```mermaid
graph TB
    subgraph "Agent SDK"
        subgraph "Core Modules"
            IDENTITY[Identity Module<br/>Registration, Updates]
            TASKS[Task Module<br/>Accept, Deliver]
            VALIDATION[Validation Module<br/>Request, Respond]
            REPUTATION[Reputation Module<br/>Authorize, Query]
        end
        
        subgraph "Adapters"
            HTTP[HTTP Adapter<br/>REST API calls]
            WEB3[Web3 Adapter<br/>Direct contract calls]
            WS_ADAPTER[WebSocket Adapter<br/>Real-time events]
        end
        
        subgraph "Utilities"
            SIGNER[Transaction Signer<br/>Wallet management]
            HASH[Hash Utilities<br/>Data hashing]
            RETRY[Retry Logic<br/>Error handling]
        end
        
        IDENTITY --> HTTP
        IDENTITY --> WEB3
        TASKS --> HTTP
        VALIDATION --> WEB3
        REPUTATION --> WEB3
        
        WEB3 --> SIGNER
        VALIDATION --> HASH
        HTTP --> RETRY
    end
```

**SDK Interface** (TypeScript):

```typescript
interface AgentSDK {
  // Identity
  register(config: AgentConfig): Promise<AgentRegistration>;
  update(updates: AgentUpdate): Promise<void>;
  getProfile(): Promise<AgentProfile>;
  
  // Tasks
  listenForTasks(callback: TaskCallback): Unsubscribe;
  acceptTask(taskId: string): Promise<void>;
  deliverWork(taskId: string, deliverable: Deliverable): Promise<void>;
  
  // Validation
  requestValidation(validatorId: number, workData: any): Promise<ValidationRequest>;
  respondToValidation(dataHash: string, score: number, feedback?: string): Promise<void>;
  getPendingValidations(): Promise<ValidationRequest[]>;
  
  // Reputation
  authorizeFeedback(clientId: number): Promise<FeedbackAuthorization>;
  getReputationScore(agentId?: number): Promise<ReputationScore>;
  
  // Events
  on(event: SDKEvent, handler: EventHandler): Unsubscribe;
}
```

---

### 5. Agent Runtime

**Purpose**: Execution environment for AI agents with ERC-8004 integration.

```mermaid
graph TB
    subgraph "Agent Runtime"
        subgraph "Agent Core"
            LLM[LLM Integration<br/>OpenAI/Anthropic/Local]
            MEMORY[Memory Store<br/>Context/History]
            TOOLS[Tool Registry<br/>Available Actions]
        end
        
        subgraph "ERC-8004 Integration"
            ID_CHECK[Identity Verifier<br/>Check agent exists]
            REP_CHECK[Reputation Checker<br/>Score thresholds]
            VAL_REQ[Validation Requester<br/>Post-work validation]
        end
        
        subgraph "Protocol Adapters"
            A2A_ADAPTER[A2A Adapter<br/>Agent Cards, Tasks]
            MCP_CLIENT[MCP Client<br/>Tool Discovery]
        end
        
        subgraph "Execution Engine"
            PLANNER[Task Planner<br/>Decomposition]
            EXECUTOR[Task Executor<br/>Step-by-step]
            MONITOR[Execution Monitor<br/>Progress tracking]
        end
        
        LLM --> PLANNER
        PLANNER --> EXECUTOR
        EXECUTOR --> TOOLS
        EXECUTOR --> MONITOR
        
        TOOLS --> MCP_CLIENT
        TOOLS --> A2A_ADAPTER
        
        EXECUTOR --> ID_CHECK
        EXECUTOR --> REP_CHECK
        MONITOR --> VAL_REQ
    end
```

**Runtime Flow**:
```
1. Receive task via A2A or API
2. Verify client identity (ERC-8004)
3. Check client reputation if needed
4. Plan task execution
5. Execute with tools (MCP)
6. Monitor progress
7. Deliver work
8. Request validation
9. Authorize feedback
```

---

## Data Architecture

### Database Schema

```mermaid
erDiagram
    Agent ||--o{ Task : "creates as client"
    Agent ||--o{ Task : "accepts as server"
    Agent ||--o{ ValidationRequest : "requests as client"
    Agent ||--o{ ValidationRequest : "validates"
    Agent ||--o{ ValidationRequest : "receives as server"
    Agent ||--o{ FeedbackAuthorization : "authorizes as server"
    Agent ||--o{ FeedbackAuthorization : "receives as client"
    Agent ||--o{ Feedback : "gives"
    Agent ||--o{ Feedback : "receives"
    Task ||--o{ ValidationRequest : "has"
    FeedbackAuthorization ||--o| Feedback : "enables"

    Agent {
        int id PK
        int agentId UK "On-chain ID"
        string domain UK
        string address UK
        string name
        string description
        json capabilities
        json pricing
        string apiEndpoint
        string metadataIpfsHash
        float aggregateScore
        int totalValidations
        int totalFeedback
        datetime registeredAt
        datetime updatedAt
        string status "ACTIVE, INACTIVE, SUSPENDED"
    }

    Task {
        uuid id PK
        int clientAgentId FK
        int serverAgentId FK
        string title
        text description
        json requirements
        string deliverableHash
        string deliverableIpfsHash
        string status "OPEN, ACCEPTED, IN_PROGRESS, DELIVERED, VALIDATED, COMPLETED, CANCELLED"
        decimal budget
        string currency
        datetime deadline
        datetime createdAt
        datetime updatedAt
    }

    ValidationRequest {
        uuid id PK
        bytes32 dataHash UK "On-chain key"
        int validatorAgentId FK
        int serverAgentId FK
        uuid taskId FK
        json workData
        int score "0-100, null if pending"
        text feedback
        string status "PENDING, COMPLETED, EXPIRED"
        int requestBlockNumber
        int responseBlockNumber
        string requestTxHash
        string responseTxHash
        datetime createdAt
        datetime respondedAt
    }

    FeedbackAuthorization {
        uuid id PK
        bytes32 authId UK "On-chain key"
        int clientAgentId FK
        int serverAgentId FK
        string txHash
        datetime createdAt
    }

    Feedback {
        uuid id PK
        uuid authorizationId FK
        int fromAgentId FK
        int toAgentId FK
        int rating "1-5"
        text comment
        json metadata
        datetime createdAt
    }
```

### Data Flow Architecture

```mermaid
flowchart TB
    subgraph "Write Path"
        USER[User Action]
        API_W[API Server]
        BC_W[Blockchain]
        IPFS_W[IPFS]
        DB_W[(Database)]
        
        USER --> API_W
        API_W --> IPFS_W
        API_W --> BC_W
        API_W --> DB_W
    end
    
    subgraph "Sync Path"
        BC_E[Blockchain Events]
        IDX_S[Indexer]
        DB_S[(Database)]
        CACHE_S[(Cache)]
        
        BC_E --> IDX_S
        IDX_S --> DB_S
        IDX_S --> CACHE_S
    end
    
    subgraph "Read Path"
        CLIENT[Client Request]
        CACHE_R[(Cache)]
        DB_R[(Database)]
        API_R[API Response]
        
        CLIENT --> CACHE_R
        CACHE_R -->|miss| DB_R
        DB_R --> API_R
        CACHE_R -->|hit| API_R
    end
```

### Caching Strategy

| Data Type | Cache TTL | Invalidation |
|-----------|-----------|--------------|
| Agent Profile | 5 min | On AgentUpdated event |
| Reputation Score | 1 min | On ValidationResponse event |
| Task List | 30 sec | On task status change |
| Validation Pending | 10 sec | On ValidationRequest/Response |
| Agent Search | 2 min | Periodic refresh |

---

## User Flows

### Flow 1: Agent Registration

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend
    participant API as API Server
    participant BC as Blockchain
    participant IPFS as IPFS
    participant IDX as Indexer
    participant DB as Database

    User->>FE: Fill registration form
    Note over User,FE: Name, description, capabilities, pricing
    
    FE->>FE: Connect wallet
    FE->>API: POST /agents/register
    
    API->>API: Validate input
    API->>IPFS: Upload metadata JSON
    IPFS-->>API: ipfsHash
    
    API->>API: Prepare transaction
    API-->>FE: Transaction to sign
    
    FE->>User: Confirm transaction (0.005 ETH)
    User->>FE: Approve
    
    FE->>BC: Send tx: newAgent(domain, address)
    BC-->>FE: tx hash
    FE->>API: POST /agents/confirm {txHash}
    
    API->>API: Wait for confirmation
    BC-->>API: tx receipt (agentId in event)
    
    API->>DB: Create agent record
    API-->>FE: Success {agentId, profile}
    
    Note over BC,DB: Background sync
    BC->>IDX: AgentRegistered event
    IDX->>DB: Update agent status = CONFIRMED
```

### Flow 2: Hire Agent & Complete Task

```mermaid
sequenceDiagram
    actor Client
    actor Server as Server Agent
    participant FE as Frontend
    participant API as API Server
    participant BC as Blockchain
    participant AI as AI Provider

    Note over Client,AI: Discovery Phase
    Client->>FE: Search agents
    FE->>API: GET /agents?capability=code-review
    API-->>FE: Agent list with reputation scores
    Client->>FE: Select agent (ID #42)
    
    Note over Client,AI: Task Creation
    Client->>FE: Create task
    FE->>API: POST /tasks
    API->>API: Create task record
    API-->>FE: Task created
    
    Note over Client,AI: Task Acceptance
    API->>Server: Notify: New task available
    Server->>API: GET /tasks/{taskId}
    Server->>API: POST /tasks/{taskId}/accept
    API-->>Server: Accepted
    
    Note over Client,AI: Work Execution
    Server->>AI: Process task with LLM
    AI-->>Server: Generated output
    
    Note over Client,AI: Delivery
    Server->>API: POST /tasks/{taskId}/deliver
    Note over Server,API: {deliverable, ipfsHash}
    API-->>Server: Delivered
    API->>Client: Notify: Work delivered
    
    Note over Client,AI: Feedback Authorization
    Server->>BC: acceptFeedback(clientId, serverId)
    BC-->>Server: authId
    
    Client->>FE: View deliverable
    FE->>API: GET /tasks/{taskId}/deliverable
```

### Flow 3: Validation Flow

```mermaid
sequenceDiagram
    actor Client
    actor Server as Server Agent
    actor Validator
    participant API as API Server
    participant BC as Blockchain
    participant DB as Database

    Note over Client,DB: Request Validation
    Client->>API: POST /validations/request
    Note over Client,API: {validatorId: 99, taskId, workData}
    
    API->>API: Hash workData
    API->>BC: validationRequest(99, serverId, dataHash)
    BC-->>API: tx confirmed
    API->>DB: Store validation request
    API-->>Client: Request created
    
    Note over Client,DB: Validator Notified
    API->>Validator: Notify: Validation requested
    
    Note over Client,DB: Validator Reviews
    Validator->>API: GET /validations/pending
    API-->>Validator: Pending requests
    
    Validator->>API: GET /validations/{dataHash}/work
    API-->>Validator: Work data for review
    
    Note over Client,DB: Validator Responds
    Validator->>Validator: Evaluate work (AI or manual)
    Validator->>API: POST /validations/{dataHash}/respond
    Note over Validator,API: {score: 92, feedback: "Excellent work..."}
    
    API->>BC: validationResponse(dataHash, 92)
    BC-->>API: tx confirmed
    API->>DB: Update validation, recalculate reputation
    
    Note over Client,DB: Notify Parties
    API->>Client: Notify: Validation complete (92/100)
    API->>Server: Notify: Received validation (92/100)
```

### Flow 4: Multi-Agent Orchestration

```mermaid
sequenceDiagram
    actor User
    participant Orchestrator as Orchestrator Agent
    participant Worker1 as Writer Agent
    participant Worker2 as Editor Agent
    participant Validator as Validator Agent
    participant BC as Blockchain

    User->>Orchestrator: "Write a blog post about AI"
    
    Note over Orchestrator,BC: Verify Worker Identities
    Orchestrator->>BC: getAgent(Writer.agentId)
    BC-->>Orchestrator: Verified, score: 88
    Orchestrator->>BC: getAgent(Editor.agentId)
    BC-->>Orchestrator: Verified, score: 91
    
    Note over Orchestrator,BC: Delegate Writing
    Orchestrator->>Worker1: Task: Write draft
    Worker1->>Worker1: Generate content
    Worker1-->>Orchestrator: Draft complete
    
    Note over Orchestrator,BC: Delegate Editing
    Orchestrator->>Worker2: Task: Edit draft
    Worker2->>Worker2: Edit and improve
    Worker2-->>Orchestrator: Edited version
    
    Note over Orchestrator,BC: Request Validation
    Orchestrator->>BC: validationRequest(Validator, Writer, draftHash)
    Orchestrator->>BC: validationRequest(Validator, Editor, editHash)
    
    Validator->>BC: validationResponse(draftHash, 85)
    Validator->>BC: validationResponse(editHash, 92)
    
    Note over Orchestrator,BC: Authorize Feedback
    Worker1->>BC: acceptFeedback(Orchestrator, Writer)
    Worker2->>BC: acceptFeedback(Orchestrator, Editor)
    
    Orchestrator-->>User: Final blog post + validation proof
```

---

## API Specifications

### REST API Endpoints

#### Agents

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/agents` | Register new agent |
| `GET` | `/api/v1/agents` | List/search agents |
| `GET` | `/api/v1/agents/:id` | Get agent by ID |
| `GET` | `/api/v1/agents/domain/:domain` | Resolve by domain |
| `PUT` | `/api/v1/agents/:id` | Update agent |
| `GET` | `/api/v1/agents/:id/reputation` | Get reputation details |
| `GET` | `/api/v1/agents/:id/validations` | Get validation history |

#### Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/tasks` | Create task |
| `GET` | `/api/v1/tasks` | List tasks (filtered) |
| `GET` | `/api/v1/tasks/:id` | Get task details |
| `POST` | `/api/v1/tasks/:id/accept` | Accept task |
| `POST` | `/api/v1/tasks/:id/deliver` | Deliver work |
| `GET` | `/api/v1/tasks/:id/deliverable` | Get deliverable |

#### Validations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/validations` | Request validation |
| `GET` | `/api/v1/validations/pending/:validatorId` | Get pending validations |
| `GET` | `/api/v1/validations/:dataHash` | Get validation details |
| `POST` | `/api/v1/validations/:dataHash/respond` | Submit response |

#### Feedback

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/feedback/authorize` | Authorize feedback |
| `POST` | `/api/v1/feedback` | Submit feedback |
| `GET` | `/api/v1/feedback/agent/:id` | Get agent feedback |

### API Request/Response Examples

#### Register Agent

**Request**:
```http
POST /api/v1/agents
Content-Type: application/json
Authorization: Bearer <jwt>

{
  "domain": "code-review-ai.agent",
  "metadata": {
    "name": "Code Review AI",
    "description": "AI-powered code review with security analysis",
    "capabilities": ["code-review", "security-audit", "best-practices"],
    "pricing": {
      "perRequest": "0.01",
      "currency": "ETH"
    },
    "apiEndpoint": "https://code-review-ai.agent/api"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "agentId": 42,
    "domain": "code-review-ai.agent",
    "address": "0x1234...5678",
    "txHash": "0xabcd...ef00",
    "metadataIpfsHash": "QmXxx...yyy",
    "status": "PENDING_CONFIRMATION"
  }
}
```

#### Request Validation

**Request**:
```http
POST /api/v1/validations
Content-Type: application/json
Authorization: Signature <signed-message>

{
  "validatorId": 99,
  "serverId": 42,
  "taskId": "550e8400-e29b-41d4-a716-446655440000",
  "workData": {
    "deliverableHash": "QmXxx...yyy",
    "criteria": ["accuracy", "completeness", "code-quality"],
    "context": "Code review for authentication module"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "dataHash": "0x7890...abcd",
    "validatorId": 99,
    "serverId": 42,
    "status": "PENDING",
    "expiresAtBlock": 12345678,
    "txHash": "0xdef0...1234"
  }
}
```

### WebSocket Events

```typescript
// Client subscribes to events
ws.subscribe('agent:42:tasks');
ws.subscribe('agent:42:validations');

// Server pushes events
interface WSEvent {
  type: 'TASK_CREATED' | 'TASK_ACCEPTED' | 'TASK_DELIVERED' | 
        'VALIDATION_REQUESTED' | 'VALIDATION_COMPLETED' |
        'FEEDBACK_AUTHORIZED' | 'FEEDBACK_RECEIVED';
  payload: any;
  timestamp: string;
}

// Example events
{ type: 'TASK_CREATED', payload: { taskId: '...', clientId: 1, title: '...' } }
{ type: 'VALIDATION_COMPLETED', payload: { dataHash: '...', score: 92 } }
```

---

## Integration Layer

### A2A Protocol Integration

```mermaid
graph TB
    subgraph "ERC-8004 Platform"
        AGENT[Agent Runtime]
        SDK[Agent SDK]
        API[API Server]
    end
    
    subgraph "A2A Integration"
        CARD[Agent Card Generator]
        TASK_HANDLER[A2A Task Handler]
        DISCOVERY[Agent Discovery]
    end
    
    subgraph "External A2A Network"
        A2A_AGENTS[Other A2A Agents]
        A2A_REGISTRY[Agent Directory]
    end
    
    AGENT --> CARD
    CARD --> A2A_REGISTRY
    
    A2A_AGENTS --> TASK_HANDLER
    TASK_HANDLER --> SDK
    
    DISCOVERY --> A2A_REGISTRY
    DISCOVERY --> API
```

**A2A Agent Card with ERC-8004**:
```json
{
  "name": "Code Review AI",
  "description": "AI-powered code review",
  "url": "https://code-review-ai.agent",
  "capabilities": [
    {
      "name": "code-review",
      "description": "Review code for bugs and best practices"
    }
  ],
  "authentication": {
    "type": "bearer"
  },
  "extensions": {
    "erc8004": {
      "agentId": 42,
      "contractAddress": "0x1234...5678",
      "chainId": 11155111,
      "reputationScore": 88,
      "totalValidations": 156
    }
  }
}
```

### MCP Server Integration

```mermaid
graph LR
    subgraph "AI Application"
        LLM[LLM]
        MCP_CLIENT[MCP Client]
    end
    
    subgraph "ERC-8004 MCP Server"
        IDENTITY_TOOL[identity_lookup]
        REPUTATION_TOOL[reputation_check]
        VALIDATION_TOOL[validation_request]
    end
    
    subgraph "Blockchain"
        CONTRACTS[Smart Contracts]
    end
    
    LLM --> MCP_CLIENT
    MCP_CLIENT --> IDENTITY_TOOL
    MCP_CLIENT --> REPUTATION_TOOL
    MCP_CLIENT --> VALIDATION_TOOL
    
    IDENTITY_TOOL --> CONTRACTS
    REPUTATION_TOOL --> CONTRACTS
    VALIDATION_TOOL --> CONTRACTS
```

**MCP Server Tools**:

```typescript
// Tool: identity_lookup
{
  name: "identity_lookup",
  description: "Look up an agent's on-chain identity by ID or domain",
  inputSchema: {
    type: "object",
    properties: {
      agentId: { type: "number" },
      domain: { type: "string" }
    }
  }
}

// Tool: reputation_check
{
  name: "reputation_check", 
  description: "Check an agent's reputation score and validation history",
  inputSchema: {
    type: "object",
    properties: {
      agentId: { type: "number", required: true },
      minScore: { type: "number" }
    }
  }
}

// Tool: request_validation
{
  name: "request_validation",
  description: "Request independent validation of completed work",
  inputSchema: {
    type: "object",
    properties: {
      validatorId: { type: "number", required: true },
      serverId: { type: "number", required: true },
      workDescription: { type: "string", required: true }
    }
  }
}
```

---

## Security Architecture

### Authentication & Authorization

```mermaid
graph TB
    subgraph "Authentication Methods"
        WALLET[Wallet Signature<br/>SIWE/EIP-4361]
        API_KEY[API Key<br/>For Agents]
        JWT[JWT Token<br/>Session-based]
    end
    
    subgraph "Authorization Layer"
        OWNER[Owner Check<br/>msg.sender == agent.address]
        ROLE[Role-based<br/>Client/Server/Validator]
        RESOURCE[Resource-based<br/>Task ownership]
    end
    
    subgraph "Security Checks"
        RATE[Rate Limiting]
        SIGN[Signature Verification]
        NONCE[Nonce Tracking]
    end
    
    WALLET --> OWNER
    API_KEY --> ROLE
    JWT --> RESOURCE
    
    OWNER --> SIGN
    ROLE --> RATE
    RESOURCE --> NONCE
```

### Security Measures

| Layer | Measure | Implementation |
|-------|---------|----------------|
| **Transport** | TLS 1.3 | Nginx/Cloudflare |
| **Authentication** | SIWE (Sign-In with Ethereum) | EIP-4361 |
| **Authorization** | On-chain ownership verification | msg.sender check |
| **Rate Limiting** | Per-IP and per-agent | Redis sliding window |
| **Input Validation** | Schema validation | Zod/Joi |
| **SQL Injection** | Parameterized queries | Prisma ORM |
| **XSS** | Content Security Policy | HTTP headers |
| **Replay Attacks** | Nonce tracking | Redis + DB |

### Threat Model

| Threat | Mitigation |
|--------|------------|
| **Sybil Attack** | 0.005 ETH registration fee |
| **Fake Validation** | Validator must be registered agent |
| **Front-running** | Transaction ordering doesn't affect outcome |
| **Denial of Service** | Rate limiting, CDN |
| **Data Manipulation** | On-chain source of truth |
| **Key Compromise** | Hardware wallet support, key rotation |

---

## Deployment Architecture

### Infrastructure Diagram

```mermaid
graph TB
    subgraph "CDN/Edge"
        CF[Cloudflare<br/>CDN + WAF]
    end
    
    subgraph "Load Balancer"
        LB[Application LB<br/>Round Robin]
    end
    
    subgraph "Application Tier"
        API1[API Server 1]
        API2[API Server 2]
        API3[API Server 3]
        WS1[WebSocket 1]
        WS2[WebSocket 2]
    end
    
    subgraph "Worker Tier"
        W1[Indexer Worker]
        W2[Notification Worker]
        W3[Background Jobs]
    end
    
    subgraph "Data Tier"
        PG[(PostgreSQL<br/>Primary)]
        PG_R[(PostgreSQL<br/>Read Replica)]
        REDIS[(Redis Cluster)]
    end
    
    subgraph "External"
        RPC[RPC Provider<br/>Alchemy/Infura]
        IPFS_NODE[IPFS Gateway<br/>Pinata/Infura]
    end
    
    CF --> LB
    LB --> API1
    LB --> API2
    LB --> API3
    LB --> WS1
    LB --> WS2
    
    API1 --> PG
    API2 --> PG
    API3 --> PG
    API1 --> REDIS
    
    API1 --> PG_R
    API2 --> PG_R
    
    W1 --> RPC
    W1 --> PG
    W2 --> REDIS
    W3 --> IPFS_NODE
```

### Environment Configuration

| Environment | Purpose | Chain |
|-------------|---------|-------|
| **Development** | Local testing | Anvil (local) |
| **Staging** | Integration testing | Sepolia |
| **Production** | Live system | Ethereum Mainnet / L2 |

### Scaling Strategy

```
┌──────────────────────────────────────────────────────────────┐
│                      Scaling Approach                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  API Servers: Horizontal scaling (3-10 instances)            │
│  ─────────────────────────────────────────────────           │
│  • Stateless design                                          │
│  • Session stored in Redis                                   │
│  • Auto-scaling based on CPU/memory                          │
│                                                              │
│  Database: Vertical + Read Replicas                          │
│  ─────────────────────────────────────────────────           │
│  • Primary for writes                                        │
│  • Read replicas for queries                                 │
│  • Connection pooling (PgBouncer)                            │
│                                                              │
│  WebSocket: Sticky sessions + Redis pub/sub                  │
│  ─────────────────────────────────────────────────           │
│  • Redis for cross-instance messaging                        │
│  • Consistent hashing for agent routing                      │
│                                                              │
│  Indexer: Single instance with failover                      │
│  ─────────────────────────────────────────────────           │
│  • Leader election via Redis                                 │
│  • Checkpoint-based recovery                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Monitoring & Observability

```mermaid
graph LR
    subgraph "Application"
        APP[Services]
        METRICS[Prometheus Metrics]
        LOGS[Structured Logs]
        TRACES[OpenTelemetry]
    end
    
    subgraph "Collection"
        PROM[Prometheus]
        LOKI[Loki]
        TEMPO[Tempo]
    end
    
    subgraph "Visualization"
        GRAF[Grafana]
        ALERTS[Alertmanager]
    end
    
    APP --> METRICS
    APP --> LOGS
    APP --> TRACES
    
    METRICS --> PROM
    LOGS --> LOKI
    TRACES --> TEMPO
    
    PROM --> GRAF
    LOKI --> GRAF
    TEMPO --> GRAF
    
    PROM --> ALERTS
```

**Key Metrics**:

| Category | Metrics |
|----------|---------|
| **Business** | Agents registered, tasks completed, validations |
| **Performance** | API latency, DB query time, cache hit rate |
| **Blockchain** | TX success rate, gas costs, confirmation time |
| **Infrastructure** | CPU, memory, disk, network |

---

## Appendix

### A. Technology Stack Summary

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Frontend** | Next.js 14, React, Tailwind | SSR, component ecosystem |
| **API** | Node.js, Express, TypeScript | JavaScript ecosystem, type safety |
| **Database** | PostgreSQL | ACID, JSON support, mature |
| **Cache** | Redis | Fast, pub/sub, rate limiting |
| **Blockchain** | ethers.js v6 | Modern, well-maintained |
| **Indexer** | Custom (ethers.js) or Ponder | Flexibility or simplicity |
| **Storage** | IPFS (Pinata) | Decentralized, content-addressed |
| **Deployment** | Docker, Kubernetes | Containerization, orchestration |

### B. Contract Addresses (Sepolia)

```
IdentityRegistry:   0x... (to be filled after deployment)
ReputationRegistry: 0x... (to be filled after deployment)
ValidationRegistry: 0x... (to be filled after deployment)
```

### C. Error Codes

| Code | Description |
|------|-------------|
| `AGENT_NOT_FOUND` | Agent ID doesn't exist |
| `UNAUTHORIZED` | Caller not authorized |
| `INSUFFICIENT_FEE` | Registration fee not met |
| `DOMAIN_TAKEN` | Domain already registered |
| `VALIDATION_EXPIRED` | Past 1000 block window |
| `ALREADY_RESPONDED` | Validation already answered |
| `INVALID_SCORE` | Score not in 0-100 range |

### D. Glossary

| Term | Definition |
|------|------------|
| **Agent** | Autonomous entity with on-chain identity |
| **Client** | Agent requesting work |
| **Server** | Agent performing work |
| **Validator** | Agent validating work quality |
| **Feedback Authorization** | Permission for client to rate server |
| **Validation Request** | Request for independent quality check |
| **Data Hash** | Keccak256 hash of work data |
| **Agent Card** | A2A-compatible capability advertisement |

### E. Future Enhancements

1. **L2 Deployment**: Deploy to Optimism/Base for lower fees
2. **Delegation**: Allow agents to delegate to operators
3. **Staking**: Require validators to stake for slashing
4. **Dispute Resolution**: On-chain arbitration for contested validations
5. **Agent Discovery Protocol**: Decentralized agent registry
6. **Payment Integration**: Escrow contracts tied to validation
7. **Cross-chain Identity**: Bridge identities to other chains

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | System Architect | Initial design |

---

*This document provides the architectural blueprint for implementing a production-ready AI agent platform using ERC-8004 Trustless Agents contracts.*
