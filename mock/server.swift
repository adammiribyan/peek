#!/usr/bin/env swift

import Foundation

// MARK: - Mock Data

let projects = [
    ["key": "DASH", "name": "Dashboard"],
    ["key": "AUTH", "name": "Authentication"],
    ["key": "API", "name": "API Platform"],
]

let tickets: [String: Any] = [
    "DASH-142": [
        "id": "10142",
        "key": "DASH-142",
        "fields": [
            "summary": "Implement dark mode toggle in user settings",
            "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
            "assignee": ["displayName": "Sarah Chen", "emailAddress": "sarah@acme.dev"],
            "reporter": ["displayName": "James Park", "emailAddress": "james@acme.dev"],
            "priority": ["name": "High"],
            "issuetype": ["name": "Story"],
            "project": ["key": "DASH", "name": "Dashboard"],
            "created": "2026-03-10T09:00:00.000+0000",
            "updated": "2026-03-26T14:30:00.000+0000",
            "description": [
                "type": "doc",
                "content": [
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Add a dark mode toggle to the user settings page. The toggle should persist the user's preference and apply the theme globally across all dashboard views. Must respect the system-level appearance setting as the default."]
                    ]],
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Acceptance Criteria:\n- Toggle visible in Settings > Appearance\n- Three options: Light, Dark, System\n- Preference persisted in user profile API\n- All chart components must support both themes\n- No flash of unstyled content on page load"]
                    ]],
                ]
            ] as [String: Any],
            "comment": [
                "comments": [
                    [
                        "author": ["displayName": "Sarah Chen"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Charts library doesn't support theming out of the box. I'll need to create a custom color palette provider. Adding 2 points to the estimate."]]]]],
                        "created": "2026-03-20T10:00:00.000+0000",
                    ],
                    [
                        "author": ["displayName": "James Park"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Approved the extra effort. Let's make sure we test with the analytics dashboard — that has the most chart variants. Also check DASH-98 for the color token spec."]]]]],
                        "created": "2026-03-21T11:30:00.000+0000",
                    ],
                    [
                        "author": ["displayName": "Sarah Chen"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "PR is up for the core toggle + persistence. Charts theming in a follow-up PR. Blocked on AUTH-67 for the profile API changes."]]]]],
                        "created": "2026-03-25T16:00:00.000+0000",
                    ],
                ]
            ],
            "issuelinks": [
                [
                    "type": ["name": "Blocks", "inward": "is blocked by", "outward": "blocks"],
                    "inwardIssue": [
                        "key": "AUTH-67",
                        "fields": [
                            "summary": "Add appearance preference to user profile API",
                            "status": ["name": "In Review", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
                            "issuetype": ["name": "Task"],
                        ]
                    ],
                ],
                [
                    "type": ["name": "Relates", "inward": "relates to", "outward": "relates to"],
                    "outwardIssue": [
                        "key": "DASH-98",
                        "fields": [
                            "summary": "Define design token color palette for theming",
                            "status": ["name": "Done", "statusCategory": ["key": "done", "name": "Done"]],
                            "issuetype": ["name": "Task"],
                        ]
                    ],
                ],
            ],
            "subtasks": [
                [
                    "key": "DASH-143",
                    "fields": [
                        "summary": "Add dark mode toggle UI component",
                        "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
                        "issuetype": ["name": "Sub-task"],
                    ]
                ],
                [
                    "key": "DASH-144",
                    "fields": [
                        "summary": "Persist theme preference in user profile",
                        "status": ["name": "To Do", "statusCategory": ["key": "new", "name": "To Do"]],
                        "issuetype": ["name": "Sub-task"],
                    ]
                ],
                [
                    "key": "DASH-145",
                    "fields": [
                        "summary": "Theme all chart components for dark mode",
                        "status": ["name": "To Do", "statusCategory": ["key": "new", "name": "To Do"]],
                        "issuetype": ["name": "Sub-task"],
                    ]
                ],
            ] as [[String: Any]],
        ] as [String: Any],
    ] as [String: Any],

    "AUTH-67": [
        "id": "10067",
        "key": "AUTH-67",
        "fields": [
            "summary": "Add appearance preference to user profile API",
            "status": ["name": "In Review", "statusCategory": ["key": "indeterminate", "name": "In Review"]],
            "assignee": ["displayName": "Marcus Rivera", "emailAddress": "marcus@acme.dev"],
            "reporter": ["displayName": "Sarah Chen", "emailAddress": "sarah@acme.dev"],
            "priority": ["name": "Medium"],
            "issuetype": ["name": "Task"],
            "project": ["key": "AUTH", "name": "Authentication"],
            "created": "2026-03-18T08:00:00.000+0000",
            "updated": "2026-03-26T09:15:00.000+0000",
            "description": [
                "type": "doc",
                "content": [
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Extend the user profile API to include an appearance preference field. Accepts: 'light', 'dark', 'system'. Default: 'system'. Must be backward-compatible — existing clients that don't send this field should not break."]
                    ]],
                ]
            ] as [String: Any],
            "comment": [
                "comments": [
                    [
                        "author": ["displayName": "Marcus Rivera"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Migration script ready. Added the column as nullable with default 'system'. PR up — waiting on review from the platform team."]]]]],
                        "created": "2026-03-24T14:00:00.000+0000",
                    ],
                ]
            ],
            "issuelinks": [
                [
                    "type": ["name": "Blocks", "inward": "is blocked by", "outward": "blocks"],
                    "outwardIssue": [
                        "key": "DASH-142",
                        "fields": [
                            "summary": "Implement dark mode toggle in user settings",
                            "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
                            "issuetype": ["name": "Story"],
                        ]
                    ],
                ],
            ],
        ] as [String: Any],
    ] as [String: Any],

    "DASH-98": [
        "id": "10098",
        "key": "DASH-98",
        "fields": [
            "summary": "Define design token color palette for theming",
            "status": ["name": "Done", "statusCategory": ["key": "done", "name": "Done"]],
            "assignee": ["displayName": "Lina Kowalski", "emailAddress": "lina@acme.dev"],
            "reporter": ["displayName": "James Park", "emailAddress": "james@acme.dev"],
            "priority": ["name": "Medium"],
            "issuetype": ["name": "Task"],
            "project": ["key": "DASH", "name": "Dashboard"],
            "created": "2026-02-20T10:00:00.000+0000",
            "updated": "2026-03-15T16:00:00.000+0000",
            "description": [
                "type": "doc",
                "content": [
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Create a comprehensive design token palette that supports light and dark themes. Tokens should cover: surfaces, text, borders, interactive states, charts, and status colors. Output as CSS custom properties and a Swift color extension."]
                    ]],
                ]
            ] as [String: Any],
            "comment": [
                "comments": [
                    [
                        "author": ["displayName": "Lina Kowalski"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Palette finalized and merged. 48 tokens total. Figma file updated with the new color system. Swift extension generated via the design-tokens CLI."]]]]],
                        "created": "2026-03-15T15:00:00.000+0000",
                    ],
                ]
            ],
            "issuelinks": [] as [[String: Any]],
        ] as [String: Any],
    ] as [String: Any],

    "DASH-143": [
        "id": "10143",
        "key": "DASH-143",
        "fields": [
            "summary": "Add dark mode toggle UI component",
            "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
            "assignee": ["displayName": "Sarah Chen", "emailAddress": "sarah@acme.dev"],
            "reporter": ["displayName": "Sarah Chen", "emailAddress": "sarah@acme.dev"],
            "priority": ["name": "Medium"],
            "issuetype": ["name": "Sub-task"],
            "project": ["key": "DASH", "name": "Dashboard"],
            "created": "2026-03-12T09:00:00.000+0000",
            "updated": "2026-03-26T10:00:00.000+0000",
            "description": [
                "type": "doc",
                "content": [
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Build the toggle component for switching between Light, Dark, and System appearance modes. Should be a segmented control in Settings > Appearance."]
                    ]],
                ]
            ] as [String: Any],
            "comment": ["comments": [] as [[String: Any]]],
            "issuelinks": [] as [[String: Any]],
            "parent": [
                "key": "DASH-142",
                "fields": [
                    "summary": "Implement dark mode toggle in user settings",
                    "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate", "name": "In Progress"]],
                    "issuetype": ["name": "Story"],
                ]
            ],
        ] as [String: Any],
    ] as [String: Any],

    "API-215": [
        "id": "10215",
        "key": "API-215",
        "fields": [
            "summary": "Rate limiter returns 500 instead of 429 under high concurrency",
            "status": ["name": "To Do", "statusCategory": ["key": "new", "name": "To Do"]],
            "assignee": ["displayName": "Unassigned", "emailAddress": ""],
            "reporter": ["displayName": "Ops Bot", "emailAddress": "ops@acme.dev"],
            "priority": ["name": "Critical"],
            "issuetype": ["name": "Bug"],
            "project": ["key": "API", "name": "API Platform"],
            "created": "2026-03-05T03:00:00.000+0000",
            "updated": "2026-03-08T11:00:00.000+0000",
            "description": [
                "type": "doc",
                "content": [
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Under sustained load (>2000 req/s), the rate limiter middleware throws an unhandled Redis connection pool exhaustion error, resulting in HTTP 500 responses instead of the expected 429. This masks legitimate rate limiting from clients and triggers false alarms in monitoring."]
                    ]],
                    ["type": "paragraph", "content": [
                        ["type": "text", "text": "Repro: Run the k6 load test script at test/load/rate-limiter.js with 200 virtual users for 60 seconds against staging."]
                    ]],
                ]
            ] as [String: Any],
            "comment": [
                "comments": [
                    [
                        "author": ["displayName": "James Park"],
                        "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "This caused a P1 incident last Friday. We need to fix the pool config and add a fallback that returns 429 when Redis is unavailable. Assigning to the platform team."]]]]],
                        "created": "2026-03-06T09:00:00.000+0000",
                    ],
                ]
            ],
            "issuelinks": [] as [[String: Any]],
        ] as [String: Any],
    ] as [String: Any],
]

// PR data keyed by issue ID
let pullRequests: [String: Any] = [
    "10142": [
        "detail": [[
            "pullRequests": [
                [
                    "id": "#347",
                    "url": "https://github.com/acme/dashboard/pull/347",
                    "status": "OPEN",
                    "name": "#347 feat: dark mode toggle and persistence",
                ],
                [
                    "id": "#352",
                    "url": "https://github.com/acme/dashboard/pull/352",
                    "status": "OPEN",
                    "name": "#352 feat: chart theming color provider",
                ],
            ]
        ]]
    ],
    "10067": [
        "detail": [[
            "pullRequests": [
                [
                    "id": "#189",
                    "url": "https://github.com/acme/auth-service/pull/189",
                    "status": "OPEN",
                    "name": "#189 feat: appearance preference in profile API",
                ],
            ]
        ]]
    ],
    "10098": [
        "detail": [[
            "pullRequests": [
                [
                    "id": "#301",
                    "url": "https://github.com/acme/dashboard/pull/301",
                    "status": "MERGED",
                    "name": "#301 chore: design token palette",
                ],
            ]
        ]]
    ],
]

// MARK: - HTTP Server

let server = try! ServerSocket(port: 8089)
print("Mock Jira server running at http://localhost:8089")

while true {
    let client = try! server.accept()
    DispatchQueue.global().async {
        let request = client.readRequest()
        let (status, body) = route(request)
        guard let json = try? JSONSerialization.data(withJSONObject: body) else {
            client.close()
            return
        }
        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        client.write(response)
        client.write(json)
        client.close()
    }
}

// MARK: - Router

func route(_ request: String) -> (String, Any) {
    let parts = request.components(separatedBy: " ")
    guard parts.count >= 2 else { return ("400 Bad Request", ["error": "bad request"]) }
    let path = parts[1]

    // GET /rest/api/3/myself
    if path == "/rest/api/3/myself" {
        return ("200 OK", ["displayName": "Demo User", "emailAddress": "demo@acme.dev"])
    }

    // GET /rest/api/3/project
    if path == "/rest/api/3/project" {
        return ("200 OK", projects)
    }

    // GET /rest/api/3/issue/{key}
    if path.hasPrefix("/rest/api/3/issue/") {
        let rawKey = String(path.split(separator: "?").first!.dropFirst("/rest/api/3/issue/".count))
        let key = rawKey.removingPercentEncoding ?? rawKey
        print("  → Issue lookup: '\(key)'")
        if let ticket = tickets[key] {
            return ("200 OK", ticket)
        }
        return ("404 Not Found", ["errorMessages": ["\(key) not found"]])
    }

    // GET /rest/dev-status/latest/issue/detail?issueId=...
    if path.hasPrefix("/rest/dev-status/latest/issue/detail") {
        if let range = path.range(of: "issueId=") {
            let idStart = path[range.upperBound...]
            let issueId = String(idStart.prefix(while: { $0 != "&" }))
            if let prs = pullRequests[issueId] {
                return ("200 OK", prs)
            }
        }
        return ("200 OK", ["detail": [["pullRequests": []]]])
    }

    return ("404 Not Found", ["error": "not found"])
}

// MARK: - Minimal TCP Socket

class ServerSocket {
    let fd: Int32
    init(port: UInt16) throws {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else { throw NSError(domain: "bind", code: Int(errno)) }
        listen(fd, 5)
    }
    func accept() throws -> ClientSocket {
        let clientFd = Darwin.accept(fd, nil, nil)
        return ClientSocket(fd: clientFd)
    }
}

class ClientSocket {
    let fd: Int32
    init(fd: Int32) { self.fd = fd }
    func readRequest() -> String {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &buf, buf.count)
        return n > 0 ? String(bytes: buf[..<n], encoding: .utf8) ?? "" : ""
    }
    func write(_ string: String) {
        let data = Array(string.utf8)
        _ = Darwin.write(fd, data, data.count)
    }
    func write(_ data: Data) {
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, data.count)
        }
    }
    func close() { Darwin.close(fd) }
}
