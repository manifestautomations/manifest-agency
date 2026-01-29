# Executive Dashboard

<!--
  Dashboard Template with Mustache-style placeholders
  Rendered by ceo-dashboard skill using aggregate-status.sh output

  Placeholders:
    {{timestamp}}           - ISO timestamp of data collection
    {{running}}             - Number of running agents
    {{blocked}}             - Number of blocked agents (pending approvals)
    {{idle}}                - Number of idle agents
    {{progress_bar}}        - ASCII progress bar [===>    ]
    {{completed}}           - Completed plans count
    {{total}}               - Total plans count
    {{avg_time}}            - Average time per task in minutes
    {{avg_trust}}           - Average trust level (0-4)
    {{warnings}}            - Agents in warning state (40-59 points)
    {{critical}}            - Agents in critical state (60+ points)
    {{cache_status}}        - [LIVE] or [CACHED Nmin]
    {{#approvals}}          - Conditional: has pending approvals
    {{/approvals}}          - End conditional
    {{#completions}}        - Conditional: has recent completions
    {{/completions}}        - End conditional
    {{#empty_approvals}}    - Conditional: no pending approvals
    {{/empty_approvals}}    - End conditional
    {{#empty_completions}}  - Conditional: no recent completions
    {{/empty_completions}}  - End conditional
-->

```
+---------------------------------------------------------------+
|  EXECUTIVE DASHBOARD                           Refresh [R]    |
+---------------------------------------------------------------+
|                                                               |
|  AGENTS             PROJECT VELOCITY        TRUST HEALTH      |
|  ---------------    ------------------      ---------------   |
|  * {{running}} Running        {{progress_bar}}          Avg: Level {{avg_trust}}   |
|  o {{blocked}} Blocked        {{completed}}/{{total}} plans done      {{warnings}} warning(s)    |
|  . {{idle}} Idle           {{avg_time}} min/task avg     {{critical}} critical       |
|                                                               |
+---------------------------------------------------------------+
```

## Needs Attention

{{#approvals}}
| Status | Type | Agent | Timeout | Action |
|--------|------|-------|---------|--------|
{{#approval_list}}
| {{status_icon}} | {{type}} | {{agent_id}} | {{timeout_display}} | [Approve] [Deny] |
{{/approval_list}}
{{/approvals}}

{{#empty_approvals}}
[OK] No pending approvals - all agents operating normally.
{{/empty_approvals}}

## Recent Completions

{{#completions}}
| Time | Issue | Result | Duration |
|------|-------|--------|----------|
{{#completion_list}}
| {{timestamp_display}} | #{{issue}} | {{result_icon}} | {{duration}} |
{{/completion_list}}
{{/completions}}

{{#empty_completions}}
[--] No recent completions in tracking window.
{{/empty_completions}}

---

```
+---------------------------------------------------------------+
|  {{cache_status}}  Last updated: {{timestamp}}               |
+---------------------------------------------------------------+
```

## Status Icons Reference

| Icon | Meaning |
|------|---------|
| `*` | Running - Agent is actively executing a task |
| `o` | Blocked - Agent is waiting for approval |
| `.` | Idle - Agent is available for work |
| `[OK]` | Healthy - No issues |
| `[!!]` | Warning - Attention may be needed |
| `[??]` | Unknown - Status could not be determined |
| `[XX]` | Error - Immediate attention required |
| `[--]` | Empty - No data available |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `R` | Refresh dashboard data |
| `A` | Jump to Approvals section |
| `C` | Jump to Completions section |
| `?` | Show help |

---

<!-- Template version: 1.0.0 -->
<!-- Compatible with aggregate-status.sh output format -->
