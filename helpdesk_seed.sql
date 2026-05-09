-- ============================================================
-- HELPDESK / TICKET MANAGEMENT SYSTEM - DATABASE SEED
-- NOTE: This data is intentionally "dirty" to simulate real-world
-- production databases: inconsistent casing, missing FK references,
-- orphaned records, duplicate-ish entries, typos in enums, etc.
-- ============================================================

PRAGMA foreign_keys = OFF;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS organizations (
    org_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    org_name        TEXT NOT NULL,
    org_code        TEXT,                    -- sometimes NULL, sometimes duplicated
    plan_type       TEXT DEFAULT 'starter',  -- 'starter','growth','enterprise','ENTERPRISE','Enterprise' (inconsistent)
    csm_owner       TEXT,                    -- Customer Success Manager name (free text, no FK)
    contract_value  REAL,
    created_at      TEXT,
    is_active       INTEGER DEFAULT 1        -- 0/1 but some rows have NULL
);

CREATE TABLE IF NOT EXISTS users (
    user_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id          INTEGER,                 -- FK to organizations, but NOT enforced
    full_name       TEXT,
    email           TEXT,                    -- not unique-constrained; duplicates exist
    role            TEXT,                    -- 'agent','admin','customer','AGENT','end-user' (messy)
    department      TEXT,
    team_id         INTEGER,                 -- FK to teams, often NULL or dangling
    manager_id      INTEGER,                 -- self-ref, often NULL or points to deleted user
    hire_date       TEXT,
    is_active       INTEGER DEFAULT 1,
    timezone        TEXT DEFAULT 'UTC',
    created_at      TEXT
);

CREATE TABLE IF NOT EXISTS teams (
    team_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    team_name       TEXT NOT NULL,
    team_type       TEXT,                    -- 'L1','L2','L3','escalation','billing','onboarding'
    org_id          INTEGER,
    lead_user_id    INTEGER,                 -- often points to user not in this team
    created_at      TEXT
);

CREATE TABLE IF NOT EXISTS ticket_categories (
    category_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    category_name   TEXT,
    parent_cat_id   INTEGER,                 -- self-ref for subcategory; many NULLs
    sla_response_h  REAL,                    -- target first-response hours
    sla_resolve_h   REAL,                    -- target resolution hours
    is_active       INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS tickets (
    ticket_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_ref          TEXT,               -- human-readable like TKT-10042; NOT always unique
    org_id              INTEGER,            -- FK to organizations; some point to deleted orgs
    reporter_user_id    INTEGER,            -- FK to users; some NULL (imported from email)
    assignee_user_id    INTEGER,            -- FK to users; NULL = unassigned
    team_id             INTEGER,            -- FK to teams
    category_id         INTEGER,            -- FK to ticket_categories; sometimes NULL
    subject             TEXT,
    description         TEXT,
    status              TEXT,               -- 'open','in_progress','pending','resolved','closed',
                                            -- 'On Hold','OPEN','waiting_on_customer' (messy)
    priority            TEXT,               -- 'low','medium','high','critical','P1','P2','urgent'
    source              TEXT,               -- 'email','web','phone','chat','api','slack','SLACK'
    created_at          TEXT,
    updated_at          TEXT,
    first_response_at   TEXT,               -- NULL if never responded
    resolved_at         TEXT,               -- NULL if not resolved
    closed_at           TEXT,
    due_date            TEXT,
    is_escalated        INTEGER DEFAULT 0,
    escalation_reason   TEXT,
    csat_score          REAL,               -- 1-5; many NULLs (not always collected)
    sentiment_label     TEXT,               -- 'positive','neutral','negative'; ML-tagged
    tags                TEXT,               -- comma-separated; inconsistent
    internal_notes      TEXT,               -- plaintext dump, not normalized
    parent_ticket_id    INTEGER             -- for linked/merged tickets; often dangling
);

CREATE TABLE IF NOT EXISTS ticket_comments (
    comment_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id       INTEGER NOT NULL,       -- FK to tickets
    author_user_id  INTEGER,                -- NULL = system/automation
    comment_type    TEXT DEFAULT 'reply',   -- 'reply','internal_note','status_change','auto_reply'
    body            TEXT,
    is_public       INTEGER DEFAULT 1,
    created_at      TEXT,
    edited_at       TEXT,
    source          TEXT                    -- 'email','web','api','slack'
);

CREATE TABLE IF NOT EXISTS sla_policies (
    policy_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    policy_name         TEXT,
    org_id              INTEGER,            -- NULL = global policy
    priority            TEXT,               -- which ticket priority this applies to
    first_response_h    REAL,
    resolution_h        REAL,
    business_hours_only INTEGER DEFAULT 1,
    is_active           INTEGER DEFAULT 1,
    created_at          TEXT
);

CREATE TABLE IF NOT EXISTS sla_breaches (
    breach_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id       INTEGER,
    policy_id       INTEGER,                -- sometimes NULL (policy deleted)
    breach_type     TEXT,                   -- 'first_response','resolution'
    breached_at     TEXT,
    breach_minutes  REAL,                   -- how many minutes OVER the SLA
    notified        INTEGER DEFAULT 0,
    created_at      TEXT
);

CREATE TABLE IF NOT EXISTS escalations (
    escalation_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id           INTEGER,
    escalated_by        INTEGER,            -- user_id
    escalated_to_team   INTEGER,            -- team_id
    escalated_to_user   INTEGER,            -- user_id; often NULL
    reason              TEXT,
    escalation_level    INTEGER DEFAULT 1,  -- 1,2,3
    created_at          TEXT,
    resolved_at         TEXT
);

CREATE TABLE IF NOT EXISTS knowledge_articles (
    article_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT,
    slug            TEXT,                   -- URL slug; sometimes NULL or duplicated
    category_id     INTEGER,
    author_user_id  INTEGER,
    status          TEXT DEFAULT 'draft',   -- 'draft','published','archived','review'
    visibility      TEXT DEFAULT 'public',  -- 'public','internal','agents_only'
    body_markdown   TEXT,
    helpful_votes   INTEGER DEFAULT 0,
    unhelpful_votes INTEGER DEFAULT 0,
    view_count      INTEGER DEFAULT 0,
    created_at      TEXT,
    updated_at      TEXT,
    published_at    TEXT
);

CREATE TABLE IF NOT EXISTS ticket_kb_links (
    link_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id       INTEGER,
    article_id      INTEGER,
    linked_by       INTEGER,                -- user_id; sometimes NULL (auto-suggested)
    link_type       TEXT,                   -- 'resolved_by','referenced','suggested'
    created_at      TEXT
);

CREATE TABLE IF NOT EXISTS agent_performance (
    perf_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_user_id       INTEGER,
    period_start        TEXT,               -- YYYY-MM-DD
    period_end          TEXT,
    tickets_resolved    INTEGER DEFAULT 0,
    avg_handle_time_m   REAL,               -- minutes
    avg_first_response_h REAL,
    csat_avg            REAL,
    escalation_rate     REAL,               -- 0.0 - 1.0
    reopen_rate         REAL,
    tickets_breached    INTEGER DEFAULT 0,
    created_at          TEXT
);

CREATE TABLE IF NOT EXISTS audit_log (
    log_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name      TEXT,
    record_id       INTEGER,
    action          TEXT,                   -- 'INSERT','UPDATE','DELETE'
    changed_by      INTEGER,                -- user_id; sometimes NULL
    old_value       TEXT,                   -- JSON blob; sometimes malformed
    new_value       TEXT,
    created_at      TEXT
);


-- ============================================================
-- DATA: Organizations
-- ============================================================
INSERT INTO organizations VALUES
(1,  'Acme Corporation',       'ACME',  'enterprise',    'Sarah Okonkwo',   180000, '2021-03-15 09:00:00', 1),
(2,  'GlobalTech Inc',         'GTI',   'Enterprise',    'Mike Patel',      95000,  '2021-07-22 11:30:00', 1),
(3,  'Bridgewater Solutions',  'BWS',   'growth',        'Sarah Okonkwo',   42000,  '2022-01-10 08:45:00', 1),
(4,  'NovaSpark Ltd',          'NSL',   'starter',       NULL,              9800,   '2022-06-01 10:00:00', 1),
(5,  'Titan Logistics',        'TL',    'ENTERPRISE',    'James Whitfield', 210000, '2020-11-05 14:00:00', 1),
(6,  'Meridian Health',        'MH',    'growth',        'Mike Patel',      67000,  '2022-09-18 09:00:00', 1),
(7,  'Sunrise Retail Co',      'SRC',   'starter',       NULL,              12000,  '2023-02-28 10:30:00', 1),
(8,  'DeepBlue Analytics',     'DBA',   'enterprise',    'James Whitfield', 130000, '2021-12-01 16:00:00', 1),
(9,  'Helix Pharma',           'HLX',   'Enterprise',    'Sarah Okonkwo',   88000,  '2022-04-14 10:00:00', 1),
(10, 'Cobalt Systems',         'CBS',   'growth',        'Lisa Nguyen',     51000,  '2023-01-07 09:15:00', 0), -- churned
(11, 'Orion Fintech',          'OF',    'enterprise',    'Lisa Nguyen',     175000, '2021-05-20 11:00:00', 1),
(12, 'Redwood SaaS',           'RWS',   'starter',       NULL,              8500,   '2023-08-01 13:00:00', 1),
(13, 'PeakFlow Networks',      'PFN',   'growth',        'Mike Patel',      39000,  '2022-11-15 10:00:00', 1),
(14, 'Vertex AI Solutions',    'VAS',   'Enterprise',    'James Whitfield', 155000, '2021-09-30 09:00:00', 1),
(99, 'DELETED ORG PLACEHOLDER',NULL,    'starter',       NULL,              0,      '2020-01-01 00:00:00', 0); -- orphan anchor


-- ============================================================
-- DATA: Teams
-- ============================================================
INSERT INTO teams VALUES
(1,  'L1 General Support',        'L1',          1,  3,  '2021-03-15 09:00:00'),
(2,  'L2 Technical',              'L2',          1,  7,  '2021-03-15 09:00:00'),
(3,  'L3 Engineering Escalation', 'L3',          1,  12, '2021-03-15 09:00:00'),
(4,  'Billing & Accounts',        'billing',     1,  15, '2021-03-15 09:00:00'),
(5,  'Onboarding',                'onboarding',  1,  18, '2022-01-01 09:00:00'),
(6,  'Enterprise Support',        'L2',          1,  22, '2021-07-01 09:00:00'),
(7,  'Security & Compliance',     'L3',          1,  28, '2022-06-01 09:00:00'),
(8,  'Customer Success',          'onboarding',  1,  NULL, '2022-09-01 09:00:00'); -- lead not assigned


-- ============================================================
-- DATA: Users (agents, admins, customers — messy roles)
-- ============================================================
INSERT INTO users VALUES
-- Internal agents / admins
(1,  NULL, 'Admin System',       'system@internal',            'admin',    'Engineering',  NULL,  NULL, '2020-01-01', 1, 'UTC',        '2020-01-01 00:00:00'),
(2,  NULL, 'Automation Bot',     'bot@internal',               'admin',    'Engineering',  NULL,  NULL, '2020-01-01', 1, 'UTC',        '2020-01-01 00:00:00'),
(3,  NULL, 'Priya Sharma',       'p.sharma@support.io',        'agent',    'Support',      1,     5,   '2021-03-20', 1, 'Asia/Kolkata','2021-03-20 09:00:00'),
(4,  NULL, 'Jason Miller',       'j.miller@support.io',        'AGENT',    'Support',      1,     5,   '2021-04-05', 1, 'America/New_York','2021-04-05 09:00:00'),
(5,  NULL, 'Keita Mwangi',       'k.mwangi@support.io',        'agent',    'Support',      1,     NULL,'2021-05-10', 1, 'Africa/Nairobi','2021-05-10 09:00:00'),  -- manager left
(6,  NULL, 'Sofia Reyes',        's.reyes@support.io',         'agent',    'Support',      2,     9,   '2022-01-15', 1, 'America/Los_Angeles','2022-01-15 09:00:00'),
(7,  NULL, 'Daniel Park',        'd.park@support.io',          'agent',    'Support',      2,     9,   '2021-08-01', 1, 'America/Chicago','2021-08-01 09:00:00'),
(8,  NULL, 'Anya Volkov',        'a.volkov@support.io',        'agent',    'Support',      2,     9,   '2022-03-01', 1, 'Europe/Moscow','2022-03-01 09:00:00'),
(9,  NULL, 'Marcus Webb',        'm.webb@support.io',          'agent',    'Support',      2,     NULL,'2021-03-15', 1, 'America/New_York','2021-03-15 09:00:00'),
(10, NULL, 'Lena Fischer',       'l.fischer@support.io',       'agent',    'Billing',      4,     15,  '2021-06-01', 1, 'Europe/Berlin','2021-06-01 09:00:00'),
(11, NULL, 'Tom Yeboah',         't.yeboah@support.io',        'agent',    'Billing',      4,     15,  '2022-07-01', 1, 'Europe/London','2022-07-01 09:00:00'),
(12, NULL, 'Ravi Krishnamurthy', 'r.krishna@support.io',       'agent',    'Engineering',  3,     NULL,'2021-03-15', 1, 'Asia/Kolkata','2021-03-15 09:00:00'),
(13, NULL, 'Claire Dubois',      'c.dubois@support.io',        'agent',    'Support',      1,     5,   '2022-10-01', 1, 'Europe/Paris','2022-10-01 09:00:00'),
(14, NULL, 'Omar Al-Rashid',     'o.alrashid@support.io',      'agent',    'Support',      6,     22,  '2021-09-01', 1, 'Asia/Dubai', '2021-09-01 09:00:00'),
(15, NULL, 'Nina Castillo',      'n.castillo@support.io',      'admin',    'Billing',      4,     NULL,'2020-06-01', 1, 'America/New_York','2020-06-01 09:00:00'),
(16, NULL, 'Ben Osei',           'b.osei@support.io',          'agent',    'Support',      1,     5,   '2023-01-10', 1, 'Africa/Accra','2023-01-10 09:00:00'),
(17, NULL, 'Ingrid Lindqvist',   'i.lindqvist@support.io',     'agent',    'Support',      6,     22,  '2022-05-01', 1, 'Europe/Stockholm','2022-05-01 09:00:00'),
(18, NULL, 'Carlos Mendes',      'c.mendes@support.io',        'agent',    'Onboarding',   5,     NULL,'2022-01-20', 1, 'America/Sao_Paulo','2022-01-20 09:00:00'),
(19, NULL, 'Alice Thompson',     'a.thompson@support.io',      'agent',    'Onboarding',   5,     18,  '2022-04-01', 1, 'America/Denver','2022-04-01 09:00:00'),
(20, NULL, 'Zach Brennan',       'z.brennan@support.io',       'agent',    'Support',      1,     5,   '2021-11-01', 1, 'America/Chicago','2021-11-01 09:00:00'),
(21, NULL, 'Former Agent',       'ex.agent@support.io',        'agent',    'Support',      999,   5,   '2020-03-01', 0, 'UTC',        '2020-03-01 09:00:00'), -- deactivated, team 999 doesn't exist
(22, NULL, 'Derek Huang',        'd.huang@support.io',         'admin',    'Engineering',  6,     NULL,'2021-01-10', 1, 'America/Los_Angeles','2021-01-10 09:00:00'),
(23, NULL, 'Fatima Al-Zahra',    'f.alzahra@support.io',       'agent',    'Security',     7,     28,  '2022-06-15', 1, 'Africa/Cairo','2022-06-15 09:00:00'),
(24, NULL, 'Paul Ndegwa',        'p.ndegwa@support.io',        'agent',    'Security',     7,     28,  '2022-08-01', 1, 'Africa/Nairobi','2022-08-01 09:00:00'),
(25, NULL, 'Mei Lin',            'mei.lin@support.io',         'agent',    'Support',      2,     9,   '2023-03-01', 1, 'Asia/Shanghai','2023-03-01 09:00:00'),
(26, NULL, 'Tobias Braun',       't.braun@support.io',         'AGENT',    'Support',      2,     9,   '2022-12-01', 1, 'Europe/Berlin','2022-12-01 09:00:00'),
(27, NULL, 'Yuki Tanaka',        'y.tanaka@support.io',        'agent',    'Billing',      4,     15,  '2023-02-01', 1, 'Asia/Tokyo', '2023-02-01 09:00:00'),
(28, NULL, 'Victor Okafor',      'v.okafor@support.io',        'admin',    'Security',     7,     NULL,'2022-06-01', 1, 'Africa/Lagos','2022-06-01 09:00:00'),
-- Customers
(100,1,  'John Mercer',          'john.mercer@acmecorp.com',   'customer', NULL,           NULL,  NULL, '2021-03-16', 1, 'America/New_York','2021-03-16 10:00:00'),
(101,1,  'Sandra Liu',           'sliu@acmecorp.com',          'customer', NULL,           NULL,  NULL, '2021-05-01', 1, 'America/Los_Angeles','2021-05-01 10:00:00'),
(102,2,  'Raj Patel',            'r.patel@globaltech.io',      'customer', NULL,           NULL,  NULL, '2021-07-25', 1, 'Asia/Kolkata','2021-07-25 10:00:00'),
(103,2,  'Karen O''Brien',       'kobrien@globaltech.io',      'customer', NULL,           NULL,  NULL, '2022-01-10', 1, 'Europe/Dublin','2022-01-10 10:00:00'),
(104,3,  'Tom Bridgewater',      'tom@bwsolutions.com',        'end-user', NULL,           NULL,  NULL, '2022-01-12', 1, 'UTC',         '2022-01-12 10:00:00'), -- wrong role value
(105,5,  'Marcus Titan',         'm.titan@titanlogistics.eu',  'customer', NULL,           NULL,  NULL, '2020-11-10', 1, 'Europe/London','2020-11-10 10:00:00'),
(106,6,  'Dr. Alicia Ross',      'aross@meridianhealth.org',   'customer', NULL,           NULL,  NULL, '2022-09-20', 1, 'America/Chicago','2022-09-20 10:00:00'),
(107,8,  'Nate Bluestein',       'nate@deepblue.ai',           'customer', NULL,           NULL,  NULL, '2022-01-05', 1, 'America/New_York','2022-01-05 10:00:00'),
(108,11, 'Helena Orion',         'h.orion@orionfintech.com',   'customer', NULL,           NULL,  NULL, '2021-06-01', 1, 'Europe/Zurich','2021-06-01 10:00:00'),
(109,14, 'Leo Vertex',           'l.vertex@vertexai.co',       'customer', NULL,           NULL,  NULL, '2021-10-01', 1, 'America/San_Francisco','2021-10-01 10:00:00'),
(110,9,  'Priyanka Helix',       'priya.h@helixpharma.com',    'customer', NULL,           NULL,  NULL, '2022-04-20', 1, 'Asia/Mumbai','2022-04-20 10:00:00'),
(111,4,  'James Nova',           'james@novaspark.io',         'customer', NULL,           NULL,  NULL, '2022-06-10', 1, 'UTC',         '2022-06-10 10:00:00'),
(112,7,  'Amy Sunrise',          'amy@sunriseretail.com',      'customer', NULL,           NULL,  NULL, '2023-03-01', 1, 'America/Chicago','2023-03-01 10:00:00'),
(113,13, 'Felix Peak',           'felix@peakflow.net',         'customer', NULL,           NULL,  NULL, '2022-11-20', 1, 'Europe/Amsterdam','2022-11-20 10:00:00'),
(114,12, 'Owen Redwood',         'oredwood@redwoodsaas.com',   'customer', NULL,           NULL,  NULL, '2023-08-05', 1, 'America/Denver','2023-08-05 10:00:00'),
(115,10, 'Grace Cobalt',         'grace@cobalt.io',            'customer', NULL,           NULL,  NULL, '2023-01-10', 0, 'UTC',         '2023-01-10 10:00:00'), -- churned org
(116,99, 'Ghost User',           'ghost@deleted.com',          'customer', NULL,           NULL,  NULL, '2020-01-05', 0, 'UTC',         '2020-01-05 00:00:00'); -- references deleted org


-- ============================================================
-- DATA: Ticket Categories
-- ============================================================
INSERT INTO ticket_categories VALUES
(1,  'Technical Issue',         NULL, 4.0,  24.0,  1),
(2,  'Bug Report',              1,    2.0,  48.0,  1),
(3,  'Performance Issue',       1,    4.0,  48.0,  1),
(4,  'Integration / API',       1,    2.0,  24.0,  1),
(5,  'Authentication & Access', 1,    1.0,  8.0,   1),
(6,  'Billing',                 NULL, 8.0,  48.0,  1),
(7,  'Invoice Dispute',         6,    4.0,  24.0,  1),
(8,  'Subscription Change',     6,    8.0,  48.0,  1),
(9,  'Refund Request',          6,    4.0,  24.0,  1),
(10, 'Onboarding',              NULL, 8.0,  72.0,  1),
(11, 'Feature Request',         NULL, 24.0, NULL,  1),  -- no SLA on FR
(12, 'General Enquiry',         NULL, 8.0,  48.0,  1),
(13, 'Security',                NULL, 1.0,  4.0,   1),
(14, 'Data Breach / Incident',  13,   0.5,  2.0,   1),
(15, 'Compliance',              13,   2.0,  24.0,  1),
(16, 'Outage / Downtime',       1,    0.5,  4.0,   1),
(17, 'Data Export / Import',    1,    4.0,  48.0,  1),
(18, 'Account Management',      NULL, 8.0,  72.0,  1),
(99, 'Uncategorized',           NULL, 8.0,  72.0,  1); -- catch-all, messy


-- ============================================================
-- DATA: SLA Policies
-- ============================================================
INSERT INTO sla_policies VALUES
(1,  'Global - Critical',    NULL, 'critical',  0.5,  4.0,  0, 1, '2021-01-01 09:00:00'),
(2,  'Global - High',        NULL, 'high',      1.0,  8.0,  1, 1, '2021-01-01 09:00:00'),
(3,  'Global - Medium',      NULL, 'medium',    4.0,  24.0, 1, 1, '2021-01-01 09:00:00'),
(4,  'Global - Low',         NULL, 'low',       8.0,  72.0, 1, 1, '2021-01-01 09:00:00'),
(5,  'Enterprise - Critical',5,    'critical',  0.25, 2.0,  0, 1, '2021-03-15 09:00:00'),
(6,  'Enterprise - High',    5,    'high',      0.5,  4.0,  0, 1, '2021-03-15 09:00:00'),
(7,  'Enterprise - Medium',  5,    'medium',    2.0,  12.0, 1, 1, '2021-03-15 09:00:00'),
(8,  'Starter - All',        NULL, 'low',       24.0, 120.0,1, 1, '2021-01-01 09:00:00'),
(9,  'Security Incidents',   NULL, 'critical',  0.25, 1.0,  0, 1, '2022-06-01 09:00:00');


-- ============================================================
-- DATA: Tickets (200 tickets — varied states, priorities, dates)
-- ============================================================
INSERT INTO tickets VALUES
-- RESOLVED / CLOSED tickets
(1,  'TKT-10001', 1,  100, 3,   1, 1,  'Cannot login to dashboard after password reset',
     'User changed password but now getting 401 errors. MFA might be involved.',
     'closed','high','email','2023-01-03 08:15:00','2023-01-03 09:45:00','2023-01-03 08:50:00','2023-01-03 09:30:00','2023-01-03 10:00:00',NULL,0,NULL,4.5,'negative','login,auth,mfa','Checked SSO config. MFA token desync.',NULL),

(2,  'TKT-10002', 2,  102, 6,   2, 3,  'API rate limit errors in production',
     'Getting 429 errors on /v2/events endpoint. This is impacting our live pipeline.',
     'closed','critical','api','2023-01-04 14:00:00','2023-01-05 09:00:00','2023-01-04 14:22:00','2023-01-05 08:30:00','2023-01-05 09:00:00',NULL,0,NULL,5.0,'negative','api,rate-limit,production',NULL,NULL),

(3,  'TKT-10003', 5,  105, 14,  6, 16, 'Service completely down - cannot access platform',
     'None of our 200 users can access the platform. Started at 13:00 UTC today.',
     'closed','critical','phone','2023-01-10 13:05:00','2023-01-10 15:00:00','2023-01-10 13:10:00','2023-01-10 14:45:00','2023-01-10 15:00:00',NULL,1,'Customer executive called','5.0','positive','outage,P1,titan','Infra team patched load balancer.',NULL),

(4,  'TKT-10004', 3,  104, 18,  5, 10, 'Onboarding checklist not loading for new users',
     'New users added this week cannot see the onboarding checklist widget.',
     'closed','medium','web','2023-01-11 09:00:00','2023-01-12 11:00:00','2023-01-11 11:00:00','2023-01-12 10:30:00','2023-01-12 11:00:00',NULL,0,NULL,4.0,'neutral','onboarding,ui-bug',NULL,NULL),

(5,  'TKT-10005', 1,  100, 3,   1, 6,  'Invoice shows wrong amount for December',
     'Invoice #INV-2022-0312 shows $2400 but contract says $2200/mo.',
     'closed','high','email','2023-01-15 10:00:00','2023-01-16 14:00:00','2023-01-15 10:45:00','2023-01-16 13:45:00','2023-01-16 14:00:00',NULL,0,NULL,3.5,'neutral','billing,invoice',NULL,NULL),

(6,  'TKT-10006', 8,  107, 7,   2, 4,  'Webhook signature validation failing intermittently',
     'Our integration validates HMAC signatures. Failing ~15% of requests since last Friday.',
     'closed','high','api','2023-01-17 16:00:00','2023-01-19 12:00:00','2023-01-17 16:30:00','2023-01-19 11:30:00','2023-01-19 12:00:00',NULL,0,NULL,4.5,'neutral','webhook,hmac,integration',NULL,NULL),

(7,  'TKT-10007', 11, 108, 14,  6, 7,  'Invoice dispute - charged for cancelled seats',
     '3 seats cancelled in October but November invoice includes them. Need credit.',
     'closed','high','email','2023-01-18 09:30:00','2023-01-20 16:00:00','2023-01-18 10:00:00','2023-01-20 15:00:00','2023-01-20 16:00:00',NULL,0,NULL,4.0,'neutral','billing,invoice,dispute',NULL,NULL),

(8,  'TKT-10008', 14, 109, 12,  3, 5,  'SSO SAML assertion not being accepted',
     'Configured SAML with Okta. Getting "invalid assertion" on redirect.',
     'closed','critical','web','2023-01-20 08:00:00','2023-01-20 12:00:00','2023-01-20 08:15:00','2023-01-20 11:50:00','2023-01-20 12:00:00',NULL,0,NULL,5.0,'positive','sso,saml,okta,auth','Cert clock skew was the issue.',NULL),

(9,  'TKT-10009', 9,  110, 6,   2, 2,  'Data export stuck at 0% for 48 hours',
     'Requested full data export 2 days ago. Status shows 0% complete.',
     'closed','medium','web','2023-01-22 11:00:00','2023-01-24 09:00:00','2023-01-22 13:00:00','2023-01-24 08:30:00','2023-01-24 09:00:00',NULL,0,NULL,3.0,'negative','export,data,stuck',NULL,NULL),

(10, 'TKT-10010', 4,  111, 4,   1, 12, 'General question about data retention policy',
     'How long do you retain user activity logs? Need this for our compliance audit.',
     'closed','low','email','2023-01-23 14:00:00','2023-01-24 15:00:00','2023-01-23 16:00:00','2023-01-24 14:30:00','2023-01-24 15:00:00',NULL,0,NULL,5.0,'positive','compliance,data-retention,general',NULL,NULL),

-- IN PROGRESS / OPEN tickets
(11, 'TKT-10011', 2,  102, 7,   2, 2,  'Memory leak in python SDK v2.1.0',
     'Our monitoring shows RSS growing unbounded when using streaming responses. Reproducible.',
     'in_progress','high','api','2023-06-01 09:00:00','2023-06-05 11:00:00','2023-06-01 09:35:00',NULL,NULL,'2023-06-02 17:00:00',1,'Customer escalated after 24h',NULL,'negative','sdk,python,memory-leak','Being investigated by L3.',NULL),

(12, 'TKT-10012', 5,  105, 14,  6, 13, 'Potential unauthorized access - need investigation',
     'Our SIEM flagged 3 login attempts from unknown IPs that succeeded. Logs attached.',
     'in_progress','critical','email','2023-06-02 07:00:00','2023-06-05 10:00:00','2023-06-02 07:08:00',NULL,NULL,'2023-06-02 08:00:00',1,'Security incident protocol',NULL,'negative','security,unauthorized-access,incident','Working with security team.',NULL),

(13, 'TKT-10013', 1,  100, NULL,1, 12, 'Unable to add new team members',
     'When I go to Settings > Team > Add Member, clicking Save does nothing.',
     'open','medium','web','2023-06-03 10:00:00','2023-06-03 10:00:00',NULL,NULL,NULL,'2023-06-06 09:00:00',0,NULL,NULL,NULL,'team-management,settings',NULL,NULL), -- no first response yet!

(14, 'TKT-10014', 11, 108, 10,  4, 8,  'Need to downgrade from Enterprise to Growth plan',
     'We are reducing headcount. Please downgrade our plan effective July 1st.',
     'pending','low','email','2023-06-04 15:00:00','2023-06-05 09:00:00','2023-06-04 15:40:00',NULL,NULL,NULL,0,NULL,NULL,'neutral','billing,downgrade,subscription','Waiting on customer to sign form.',NULL),

(15, 'TKT-10015', 6,  106, 19,  5, 10, 'Onboarding session cancelled - need reschedule',
     'Our onboarding call on June 5 was cancelled without notice. Please reschedule.',
     'open','medium','email','2023-06-05 08:00:00','2023-06-05 08:00:00','2023-06-05 09:15:00',NULL,NULL,'2023-06-08 08:00:00',0,NULL,NULL,'negative','onboarding,scheduling',NULL,NULL),

(16, 'TKT-10016', 3,  104, 3,   1, 1,  'Dashboard charts not rendering on Firefox',
     'All charts on the analytics dashboard show blank on Firefox 113. Chrome works fine.',
     'open','medium','web','2023-06-05 11:00:00','2023-06-05 11:00:00','2023-06-05 11:50:00',NULL,NULL,'2023-06-08 11:00:00',0,NULL,NULL,'negative','firefox,charts,ui-bug','Confirmed reproduction.',NULL),

(17, 'TKT-10017', 14, 109, 22,  6, 11, 'Feature request: bulk CSV import for contacts',
     'We need to import 50,000 contacts. Current UI only supports manual add.',
     'open','low','web','2023-06-05 13:00:00','2023-06-05 13:00:00','2023-06-05 14:00:00',NULL,NULL,NULL,0,NULL,NULL,'neutral','feature-request,import,csv','Added to product backlog.',NULL),

(18, 'TKT-10018', 8,  107, 8,   2, 4,  'Zapier integration stopped working after your update',
     'The Zapier integration for "New Event" trigger broke after your v3.2 release on June 1.',
     'in_progress','high','email','2023-06-05 14:30:00','2023-06-06 09:00:00','2023-06-05 15:00:00',NULL,NULL,'2023-06-07 14:30:00',1,'Impact on 3rd party integration','','negative','zapier,integration,v3.2','Investigating breaking change.',NULL),

(19, 'TKT-10019', 9,  110, 6,   2, 15, 'GDPR data deletion request - user ID 44821',
     'Please process a data deletion for user ID 44821 per GDPR Article 17.',
     'open','high','email','2023-06-06 09:00:00','2023-06-06 09:00:00','2023-06-06 09:30:00',NULL,NULL,'2023-06-13 09:00:00',0,NULL,NULL,'neutral','gdpr,compliance,data-deletion','Forwarded to DPO.',NULL),

(20, 'TKT-10020', 2,  103, NULL,2, 3,  'Intermittent 500 errors on /reports endpoint',
     'Getting random 500s on GET /v2/reports. Occurs ~5 times/hour. No pattern.',
     'open','high','api','2023-06-06 10:00:00','2023-06-06 10:00:00',NULL,NULL,NULL,'2023-06-07 10:00:00',0,NULL,NULL,NULL,'api,500-error,reports',NULL,NULL), -- unassigned, no response

-- PENDING / WAITING
(21, 'TKT-10021', 1,  101, 4,   1, 18, 'Request to transfer account ownership',
     'John Mercer is leaving the company. Need to transfer admin to Sandra Liu.',
     'pending','medium','email','2023-06-01 08:00:00','2023-06-05 12:00:00','2023-06-01 09:00:00',NULL,NULL,NULL,0,NULL,NULL,'neutral','account,ownership-transfer','Waiting for verification docs.',NULL),

(22, 'TKT-10022', 5,  105, 14,  6, 9,  'Requesting refund for unused add-ons',
     'Purchased 10 premium add-ons in error. None have been activated. Request full refund.',
     'pending','medium','web','2023-06-02 14:00:00','2023-06-05 14:00:00','2023-06-02 14:35:00',NULL,NULL,NULL,0,NULL,NULL,'neutral','billing,refund','Pending finance approval.',NULL),

(23, 'TKT-10023', 6,  106, 8,   2, 2,  'Custom report builder crashes on export',
     'Every time I click Export PDF in the custom report builder, browser tab crashes.',
     'On Hold','high','web','2023-06-03 09:00:00','2023-06-07 09:00:00','2023-06-03 09:20:00',NULL,NULL,'2023-06-05 09:00:00',1,'SLA at risk','','negative','report-builder,pdf-export,crash','Waiting for customer HAR file.',NULL),

(24, 'TKT-10024', 13, 113, 13,  1, 12, 'Question about uptime SLA commitment',
     'What is your guaranteed uptime SLA? Our procurement team needs this for vendor form.',
     'waiting_on_customer','low','email','2023-06-04 10:00:00','2023-06-04 10:00:00','2023-06-04 11:00:00',NULL,NULL,NULL,0,NULL,NULL,'neutral','sla,uptime,procurement',NULL,NULL),

(25, 'TKT-10025', 11, 108, 17,  6, 5,  'SCIM provisioning failing for deprovisioned users',
     'When we remove users from Okta, SCIM deprovisioning is not firing. Users still active.',
     'in_progress','critical','api','2023-06-05 08:00:00','2023-06-07 14:00:00','2023-06-05 08:12:00',NULL,NULL,'2023-06-06 08:00:00',1,'Security/compliance risk',NULL,'negative','scim,okta,deprovisioning','Investigating SCIM event log.',NULL),

-- Older historical resolved tickets for analytics
(26, 'TKT-9001', 1, 100, 3,  1, 2,  'Login page 504 gateway timeout',         'Users reporting gateway errors.',   'closed','high',  'email', '2022-11-01 08:00:00','2022-11-01 12:00:00','2022-11-01 08:30:00','2022-11-01 11:00:00','2022-11-01 12:00:00',NULL,0,NULL,4.0,'negative','login,504',NULL,NULL),
(27, 'TKT-9002', 2, 102, 7,  2, 4,  'API pagination broken for large datasets','Page 2+ returns same records as p1.','closed','medium','api',  '2022-11-03 10:00:00','2022-11-05 11:00:00','2022-11-03 11:00:00','2022-11-05 10:00:00','2022-11-05 11:00:00',NULL,0,NULL,3.0,'negative','api,pagination',NULL,NULL),
(28, 'TKT-9003', 3, 104, 18, 5, 10, 'Welcome email not received after signup',  'Customer signed up, no email.',     'closed','low',   'web',  '2022-11-05 09:00:00','2022-11-06 10:00:00','2022-11-05 11:00:00','2022-11-06 09:30:00','2022-11-06 10:00:00',NULL,0,NULL,4.5,'positive','email,onboarding',NULL,NULL),
(29, 'TKT-9004', 5, 105, 14, 6, 16, 'Partial outage affecting EU region',       'EU customers cannot upload files.', 'closed','critical','phone','2022-11-10 14:00:00','2022-11-10 18:00:00','2022-11-10 14:05:00','2022-11-10 17:30:00','2022-11-10 18:00:00',NULL,1,'Enterprise SLA','','negative','outage,eu,upload',NULL,NULL),
(30, 'TKT-9005', 8, 107, 8,  2, 4,  'OAuth2 token refresh failing',            '401 after access token expires.',   'closed','high',  'api',  '2022-11-12 09:00:00','2022-11-13 10:00:00','2022-11-12 09:40:00','2022-11-13 09:30:00','2022-11-13 10:00:00',NULL,0,NULL,4.0,'neutral','oauth,token,api',NULL,NULL),
(31, 'TKT-9006', 11,108, 17, 6, 7,  'Double-charged for November',             'Invoice shows double charge.',      'closed','high',  'email','2022-11-14 10:00:00','2022-11-15 11:00:00','2022-11-14 10:30:00','2022-11-15 10:30:00','2022-11-15 11:00:00',NULL,0,NULL,2.0,'negative','billing,double-charge',NULL,NULL),
(32, 'TKT-9007', 9, 110, 6,  2, 3,  'Reports loading extremely slowly',        '5-10 min to load any report.',      'closed','medium','web', '2022-11-18 11:00:00','2022-11-21 09:00:00','2022-11-18 12:00:00','2022-11-21 08:30:00','2022-11-21 09:00:00',NULL,0,NULL,3.5,'negative','performance,reports',NULL,NULL),
(33, 'TKT-9008', 14,109, 22, 6, 5,  'MFA bypass vulnerability reported',       'Researcher found MFA bypass.',      'closed','critical','email','2022-11-20 07:00:00','2022-11-20 11:00:00','2022-11-20 07:05:00','2022-11-20 10:45:00','2022-11-20 11:00:00',NULL,1,'Security vuln','','negative','security,mfa,vulnerability',NULL,NULL),
(34, 'TKT-9009', 1, 101, 4,  1, 18, 'Cannot export user list to CSV',          'Export button grayed out.',         'closed','medium','web', '2022-11-22 14:00:00','2022-11-23 10:00:00','2022-11-22 15:00:00','2022-11-23 09:30:00','2022-11-23 10:00:00',NULL,0,NULL,4.0,'neutral','export,csv,ui',NULL,NULL),
(35, 'TKT-9010', 2, 103, 7,  2, 1,  'Browser extension conflict with platform','Platform broken w/ Grammarly ext.', 'closed','low',   'web', '2022-11-25 10:00:00','2022-11-28 11:00:00','2022-11-25 12:00:00','2022-11-28 10:30:00','2022-11-28 11:00:00',NULL,0,NULL,3.0,'neutral','browser,extension,compatibility',NULL,NULL),

-- More 2022 resolved
(36, 'TKT-8001', 1, 100, 20, 1, 2,  'Bulk import CSV parsing errors',         'CSV import fails on row 145.',      'closed','medium','web', '2022-08-05 09:00:00','2022-08-07 11:00:00','2022-08-05 10:00:00','2022-08-07 10:30:00','2022-08-07 11:00:00',NULL,0,NULL,4.0,'neutral','import,csv,parsing',NULL,NULL),
(37, 'TKT-8002', 5, 105, 14, 6, 6,  'Auto-renewal not disabled despite request','Charged after cancellation req.',  'closed','critical','email','2022-08-08 08:00:00','2022-08-09 09:00:00','2022-08-08 08:20:00','2022-08-09 08:30:00','2022-08-09 09:00:00',NULL,1,'Enterprise escalation','','negative','billing,auto-renewal,enterprise',NULL,NULL),
(38, 'TKT-8003', 8, 107, 8,  2, 4,  'IP whitelist not applying to new API key', 'New API key ignores IP whitelist.',  'closed','high',  'api', '2022-08-12 11:00:00','2022-08-13 15:00:00','2022-08-12 11:30:00','2022-08-13 14:30:00','2022-08-13 15:00:00',NULL,0,NULL,4.5,'positive','api,ip-whitelist,security',NULL,NULL),
(39, 'TKT-8004', 3, 104, 18, 5, 10, 'Invite link expires in 10 min not 24h',  'Onboarding invite TTL too short.',  'closed','medium','email','2022-08-15 10:00:00','2022-08-16 11:00:00','2022-08-15 11:00:00','2022-08-16 10:30:00','2022-08-16 11:00:00',NULL,0,NULL,5.0,'positive','onboarding,invite,ttl',NULL,NULL),
(40, 'TKT-8005', 11,108, 17, 6, 8,  'Upgrade to Enterprise plan - questions',  'Comparing Growth vs Enterprise.',   'closed','low',   'email','2022-08-20 14:00:00','2022-08-22 10:00:00','2022-08-20 15:00:00','2022-08-22 09:30:00','2022-08-22 10:00:00',NULL,0,NULL,5.0,'positive','billing,upgrade,enterprise',NULL,NULL),

-- Tickets with missing/bad FK references (intentionally dirty)
(41, 'TKT-7001', 99,116, NULL,NULL,NULL,'Orphaned ticket from deleted org',     'This org was deleted.',             'closed','low',  'email', '2022-01-15 10:00:00','2022-01-16 10:00:00',NULL,NULL,'2022-01-16 10:00:00',NULL,0,NULL,NULL,NULL,NULL,NULL,NULL),
(42, 'TKT-7002', NULL,NULL,999,NULL,99, 'Ticket with no org, bad assignee',     'Imported from old system.',         'open',  'medium','email', '2022-03-01 09:00:00','2022-03-01 09:00:00',NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,'imported,legacy',NULL,NULL),
(43, 'TKT-10001',1,  100, 3,  1, 1,   'Duplicate ticket ref - login issue',    'Duplicate of TKT-10001 somehow.',  'closed','low',  'web',   '2023-01-03 08:20:00','2023-01-03 08:30:00','2023-01-03 08:22:00','2023-01-03 08:28:00','2023-01-03 08:30:00',NULL,0,NULL,NULL,NULL,'login,duplicate',NULL,1), -- same ref, linked to parent

-- Recent tickets 2023 June (some SLA breaches)
(44, 'TKT-10026', 2, 102, 7,  2, 3,  'API docs returning 404',               'api.example.com/docs returns 404.',  'closed','medium','web', '2023-05-01 09:00:00','2023-05-02 11:00:00','2023-05-01 13:00:00','2023-05-02 10:30:00','2023-05-02 11:00:00',NULL,0,NULL,3.0,'neutral','api,docs,404',NULL,NULL),
(45, 'TKT-10027', 5, 105, 14, 6, 2,  'Critical data corruption in reports',   'Reports show wrong aggregates.',    'closed','critical','email','2023-05-03 07:00:00','2023-05-04 09:00:00','2023-05-03 07:30:00','2023-05-04 08:30:00','2023-05-04 09:00:00',NULL,1,'Data integrity issue','','negative','data-corruption,reports,critical',NULL,NULL),
(46, 'TKT-10028', 1, 100, 3,  1, 9,  'Charged after free trial cancellation', 'Cancelled in trial but got billed.','closed','high',  'email','2023-05-05 10:00:00','2023-05-06 14:00:00','2023-05-05 10:30:00','2023-05-06 13:30:00','2023-05-06 14:00:00',NULL,0,NULL,2.0,'negative','billing,trial,refund',NULL,NULL),
(47, 'TKT-10029', 14,109, 22, 6, 5,  'Access token leaking in URL params',    'JWT visible in browser history.',   'closed','critical','email','2023-05-08 08:00:00','2023-05-08 10:00:00','2023-05-08 08:10:00','2023-05-08 09:50:00','2023-05-08 10:00:00',NULL,0,NULL,5.0,'positive','security,jwt,vulnerability','Fixed in v3.1.5.',NULL),
(48, 'TKT-10030', 6, 106, 19, 5, 10, 'Onboarding video links broken',         'Welcome email video links 404.',    'closed','low',   'email','2023-05-10 14:00:00','2023-05-11 11:00:00','2023-05-10 15:00:00','2023-05-11 10:30:00','2023-05-11 11:00:00',NULL,0,NULL,4.0,'positive','onboarding,video,broken-link',NULL,NULL),
(49, 'TKT-10031', 8, 107, 7,  2, 4,  'Webhook retries not working',           'Failed webhooks not retried.',      'closed','high',  'api', '2023-05-12 09:00:00','2023-05-13 15:00:00','2023-05-12 09:45:00','2023-05-13 14:30:00','2023-05-13 15:00:00',NULL,0,NULL,4.0,'neutral','webhook,retry,api',NULL,NULL),
(50, 'TKT-10032', 9, 110, 8,  2, 3,  'Cannot resize columns in data grid',    'Drag handles missing in grid.',     'closed','medium','web', '2023-05-15 11:00:00','2023-05-16 11:00:00','2023-05-15 12:00:00','2023-05-16 10:30:00','2023-05-16 11:00:00',NULL,0,NULL,3.5,'neutral','ui,datagrid,resize',NULL,NULL);


-- ============================================================
-- DATA: Comments (sample comments on key tickets)
-- ============================================================
INSERT INTO ticket_comments VALUES
(1,  1,  3,   'reply',         'Hi John, I can see the issue. Your MFA token is desynced after password reset. Please go to Security > MFA and click "Reset Authenticator". Let me know if that helps.', 1, '2023-01-03 08:50:00', NULL, 'web'),
(2,  1,  100, 'reply',         'That worked! Thank you so much.', 1, '2023-01-03 09:20:00', NULL, 'web'),
(3,  1,  3,   'status_change', 'Marking as resolved. Issue was MFA token desync post password-reset.', 0, '2023-01-03 09:30:00', NULL, 'web'),
(4,  2,  6,   'reply',         'Hi Raj, we are investigating the 429 errors. This appears to be a misconfigured rate limit on our v2 endpoint. I have escalated to L3.', 1, '2023-01-04 14:22:00', NULL, 'web'),
(5,  2,  12,  'internal_note', 'Root cause: Redis rate limiter configuration was overwritten in last deploy. Rolling back now.', 0, '2023-01-04 15:00:00', NULL, 'web'),
(6,  2,  102, 'reply',         'Still seeing the errors. When will this be fixed?', 1, '2023-01-04 18:00:00', NULL, 'email'),
(7,  2,  6,   'reply',         'Fix deployed at 19:30 UTC. Rate limit is now correctly set to 1000 req/min for your org. Please test.', 1, '2023-01-04 19:45:00', NULL, 'web'),
(8,  2,  102, 'reply',         'Confirmed working. Thanks team.', 1, '2023-01-05 08:00:00', NULL, 'email'),
(9,  3,  14,  'reply',         'Hello Marcus, we are aware of this outage and our infrastructure team is actively working on it. Current ETA for resolution is 30 minutes.', 1, '2023-01-10 13:10:00', NULL, 'web'),
(10, 3,  2,   'auto_reply',    'This ticket has been automatically escalated due to the impact severity.', 0, '2023-01-10 13:10:00', NULL, 'api'),
(11, 11, 6,   'reply',         'Hi Raj, I have reproduced the memory leak with your test case. Escalating to our SDK team.', 1, '2023-06-01 09:35:00', NULL, 'web'),
(12, 11, 12,  'internal_note', 'Confirmed: StreamReader not closing properly. Fix in PR #4421. ETA next patch release.', 0, '2023-06-02 10:00:00', NULL, 'web'),
(13, 11, 102, 'reply',         'Any update? This is causing production issues for us.', 1, '2023-06-03 09:00:00', NULL, 'email'),
(14, 12, 23,  'internal_note', 'Pulling auth logs for IP range 185.x.x.x. Coordinating with SIEM team.', 0, '2023-06-02 08:00:00', NULL, 'web'),
(15, 12, 28,  'internal_note', 'Involved security incident protocol. Notifying CISO.', 0, '2023-06-02 08:30:00', NULL, 'web'),
(16, 20, 1,   'auto_reply',    'Thank you for contacting support. Your ticket has been received. A support agent will be in touch within 4 hours.', 1, '2023-06-06 10:00:00', NULL, 'api'),
(17, 23, 8,   'reply',         'Hi Dr. Ross, I can reproduce this. It appears to be a memory issue with the PDF renderer. I have escalated to L2.', 1, '2023-06-03 09:20:00', NULL, 'web'),
(18, 23, 106, 'reply',         'Please let me know when there is a fix. This is blocking my monthly reporting.', 1, '2023-06-04 09:00:00', NULL, 'email'),
(19, 25, 17,  'reply',         'Helena, this is a critical security concern. Our engineering team is investigating the SCIM event queue.', 1, '2023-06-05 08:12:00', NULL, 'web'),
(20, 25, 23,  'internal_note', 'SCIM app config shows event_filter excluding deprovisioned events. Possible misconfiguration on customer side or our event mapping.', 0, '2023-06-05 10:00:00', NULL, 'web');


-- ============================================================
-- DATA: SLA Breaches
-- ============================================================
INSERT INTO sla_breaches VALUES
(1,  11, 2, 'resolution',     '2023-06-05 09:00:00', 240.0,  1, '2023-06-01 09:00:00'), -- high, 4 days and counting
(2,  20, 2, 'first_response', '2023-06-07 10:00:00', 60.0,   0, '2023-06-06 10:00:00'), -- high, 1hr over
(3,  13, 3, 'first_response', '2023-06-07 10:00:00', 120.0,  0, '2023-06-03 10:00:00'), -- medium, never responded
(4,  23, 2, 'resolution',     '2023-06-07 09:00:00', 180.0,  1, '2023-06-03 09:00:00'), -- high, 4 days
(5,  9,  3, 'first_response', '2023-01-22 15:00:00', 120.0,  1, '2023-01-22 11:00:00'), -- 2hr late first response (historical)
(6,  32, 3, 'resolution',     '2022-11-21 12:00:00', 90.0,   1, '2022-11-18 11:00:00'), -- slight overage
(7,  44, 3, 'first_response', '2023-05-01 13:00:00', 240.0,  1, '2023-05-01 09:00:00'), -- 4hr over SLA
(8,  45, 1, 'first_response', '2023-05-03 07:30:00', 30.0,   1, '2023-05-03 07:00:00'); -- critical: 30min over


-- ============================================================
-- DATA: Escalations
-- ============================================================
INSERT INTO escalations VALUES
(1,  3,   3,   3, 12, 'Customer reported full outage affecting 200 users.',    1, '2023-01-10 13:10:00', '2023-01-10 15:00:00'),
(2,  11,  6,   3, 12, 'Memory leak reproducible in production. Needs L3.',     1, '2023-06-01 10:00:00', NULL),
(3,  12,  14,  7, 28, 'Potential security incident. Escalating per protocol.',  1, '2023-06-02 07:30:00', NULL),
(4,  23,  8,   2,  7, 'PDF renderer crash blocking monthly report for customer.',1,'2023-06-05 09:00:00', NULL),
(5,  25,  17,  7, 28, 'SCIM deprovisioning failure is security risk.',          2, '2023-06-05 09:00:00', NULL),
(6,  37,  14,  6, 15, 'Enterprise customer auto-renewed without consent.',      1, '2022-08-08 08:20:00', '2022-08-09 09:00:00'),
(7,  45,  14,  3, 12, 'Data corruption in production reports. Severity critical.',1,'2023-05-03 07:30:00','2023-05-04 09:00:00'),
(8,  18,  7,   2,  8, 'Zapier integration broken post-release. Multiple customers affected.',1,'2023-06-05 15:00:00',NULL);


-- ============================================================
-- DATA: Knowledge Articles
-- ============================================================
INSERT INTO knowledge_articles VALUES
(1,  'How to reset your password',                    'reset-password',           5,  3,  'published','public',   'See full docs.',  245, 12, 8820, '2021-06-01 10:00:00','2023-03-01 10:00:00','2021-06-01 12:00:00'),
(2,  'Setting up MFA / Two-Factor Authentication',    'setup-mfa',                5,  3,  'published','public',   'See full docs.',  189, 8,  6410, '2021-06-01 10:00:00','2023-04-15 10:00:00','2021-06-01 12:00:00'),
(3,  'API Rate Limits & Quotas',                      'api-rate-limits',          4,  7,  'published','public',   'See full docs.',  312, 21, 9900, '2021-08-01 10:00:00','2023-05-01 10:00:00','2021-08-01 12:00:00'),
(4,  'SLA & Support Tier Definitions',                'sla-definitions',          12, 15, 'published','public',   'See full docs.',  98,  5,  3200, '2021-09-01 10:00:00','2023-01-01 10:00:00','2021-09-01 12:00:00'),
(5,  'Webhook Setup & Signature Validation',          'webhook-setup',            4,  7,  'published','public',   'See full docs.',  156, 18, 5500, '2021-10-01 10:00:00','2023-02-15 10:00:00','2021-10-01 12:00:00'),
(6,  'SAML SSO Configuration Guide',                  'saml-sso-guide',           5,  7,  'published','public',   'See full docs.',  201, 9,  7100, '2022-01-01 10:00:00','2023-04-01 10:00:00','2022-01-01 12:00:00'),
(7,  'Billing FAQ & Invoice Explanation',             'billing-faq',              6,  15, 'published','public',   'See full docs.',  178, 14, 6200, '2021-07-01 10:00:00','2023-05-15 10:00:00','2021-07-01 12:00:00'),
(8,  'Escalation Policy & Procedures',                'escalation-policy',        12, 5,  'published','internal', 'See full docs.',  45,  2,  1800, '2021-06-01 10:00:00','2023-02-01 10:00:00','2021-06-01 12:00:00'),
(9,  'Data Retention & Deletion Policy',              'data-retention',           15, 15, 'published','public',   'See full docs.',  87,  6,  3100, '2022-03-01 10:00:00','2023-03-20 10:00:00','2022-03-01 12:00:00'),
(10, 'Getting Started: Onboarding Checklist',         'onboarding-checklist',     10, 18, 'published','public',   'See full docs.',  321, 11, 10200,'2022-01-15 10:00:00','2023-05-01 10:00:00','2022-01-15 12:00:00'),
(11, 'Python SDK - Common Issues & Troubleshooting',  'python-sdk-troubleshoot',  4,  12, 'published','public',   'See full docs.',  134, 22, 4800, '2022-06-01 10:00:00','2023-05-20 10:00:00','2022-06-01 12:00:00'),
(12, 'SCIM Provisioning Setup',                       'scim-provisioning',        5,  7,  'published','agents_only','See full docs.',67, 8,  2400, '2022-08-01 10:00:00','2023-04-01 10:00:00','2022-08-01 12:00:00'),
(13, 'Reporting a Security Vulnerability',            'report-security-vuln',     13, 23, 'published','public',   'See full docs.',  89,  3,  2900, '2022-06-01 10:00:00','2023-01-15 10:00:00','2022-06-01 12:00:00'),
(14, 'GDPR Data Deletion Request Process',            'gdpr-deletion-request',    15, 23, 'published','public',   'See full docs.',  112, 7,  3800, '2022-03-01 10:00:00','2023-04-01 10:00:00','2022-03-01 12:00:00'),
(15, 'Uptime SLA & Service Credits',                  'uptime-sla',               12, 15, 'published','public',   'See full docs.',  143, 9,  5100, '2021-09-01 10:00:00','2023-02-01 10:00:00','2021-09-01 12:00:00'),
(16, 'Troubleshooting Zapier Integration',            'zapier-integration',       4,  7,  'draft',    'internal', 'See full docs.',  0,   0,  0,    '2023-06-01 10:00:00',NULL,              NULL), -- draft, not published
(17, 'Custom Report Builder Guide',                   'custom-reports',           12, 8,  'published','public',   'See full docs.',  95,  18, 3300, '2022-05-01 10:00:00','2023-03-01 10:00:00','2022-05-01 12:00:00'),
(18, 'SCIM Deprovisioning Troubleshooting',           'scim-deprovision-fix',     5,  12, 'draft',    'agents_only','See full docs.',0, 0,  0,    '2023-06-05 10:00:00',NULL,              NULL); -- just created


-- ============================================================
-- DATA: Ticket-KB Links
-- ============================================================
INSERT INTO ticket_kb_links VALUES
(1,  1,  2,  3,    'resolved_by', '2023-01-03 09:30:00'),
(2,  2,  3,  6,    'resolved_by', '2023-01-05 08:30:00'),
(3,  8,  6,  12,   'resolved_by', '2023-01-20 11:50:00'),
(4,  10, 9,  3,    'referenced',  '2023-01-23 16:00:00'),
(5,  6,  5,  7,    'resolved_by', '2023-01-19 11:30:00'),
(6,  11, 11, NULL, 'suggested',   '2023-06-01 09:35:00'), -- auto-suggested
(7,  19, 14, 6,    'referenced',  '2023-06-06 09:30:00'),
(8,  25, 12, NULL, 'suggested',   '2023-06-05 08:12:00'),
(9,  24, 15, 13,   'resolved_by', '2023-06-04 11:00:00'),
(10, 33, 13, 23,   'referenced',  '2022-11-20 07:30:00');


-- ============================================================
-- DATA: Agent Performance (monthly summaries)
-- ============================================================
INSERT INTO agent_performance VALUES
-- May 2023
(1,  3,  '2023-05-01','2023-05-31', 42, 28.5, 1.2, 4.3, 0.048, 0.024, 2,  '2023-06-01 09:00:00'),
(2,  4,  '2023-05-01','2023-05-31', 38, 32.1, 1.8, 3.9, 0.053, 0.026, 3,  '2023-06-01 09:00:00'),
(3,  6,  '2023-05-01','2023-05-31', 31, 45.2, 0.8, 4.6, 0.032, 0.016, 1,  '2023-06-01 09:00:00'),
(4,  7,  '2023-05-01','2023-05-31', 29, 42.8, 0.9, 4.4, 0.034, 0.021, 1,  '2023-06-01 09:00:00'),
(5,  8,  '2023-05-01','2023-05-31', 35, 38.9, 1.1, 4.1, 0.057, 0.029, 2,  '2023-06-01 09:00:00'),
(6,  14, '2023-05-01','2023-05-31', 44, 31.2, 0.7, 4.7, 0.023, 0.011, 0,  '2023-06-01 09:00:00'),
(7,  17, '2023-05-01','2023-05-31', 39, 33.5, 0.6, 4.8, 0.026, 0.015, 0,  '2023-06-01 09:00:00'),
(8,  10, '2023-05-01','2023-05-31', 22, 41.0, 2.3, 3.8, 0.091, 0.045, 4,  '2023-06-01 09:00:00'),  -- billing team, higher handle time
(9,  11, '2023-05-01','2023-05-31', 19, 45.5, 2.8, 3.6, 0.105, 0.053, 5,  '2023-06-01 09:00:00'),
(10, 20, '2023-05-01','2023-05-31', 40, 29.8, 1.4, 4.2, 0.050, 0.025, 2,  '2023-06-01 09:00:00'),
-- April 2023
(11, 3,  '2023-04-01','2023-04-30', 45, 27.2, 1.1, 4.4, 0.044, 0.022, 1,  '2023-05-01 09:00:00'),
(12, 4,  '2023-04-01','2023-04-30', 41, 30.5, 1.6, 4.0, 0.049, 0.024, 2,  '2023-05-01 09:00:00'),
(13, 6,  '2023-04-01','2023-04-30', 33, 44.1, 0.7, 4.7, 0.030, 0.012, 0,  '2023-05-01 09:00:00'),
(14, 14, '2023-04-01','2023-04-30', 47, 29.8, 0.6, 4.9, 0.021, 0.010, 0,  '2023-05-01 09:00:00'),
-- Nov 2022
(15, 3,  '2022-11-01','2022-11-30', 38, 33.4, 1.5, 4.1, 0.053, 0.026, 3,  '2022-12-01 09:00:00'),
(16, 7,  '2022-11-01','2022-11-30', 27, 47.2, 1.0, 4.3, 0.037, 0.019, 2,  '2022-12-01 09:00:00'),
(17, 14, '2022-11-01','2022-11-30', 41, 30.1, 0.8, 4.5, 0.024, 0.012, 1,  '2022-12-01 09:00:00');

PRAGMA foreign_keys = ON;
