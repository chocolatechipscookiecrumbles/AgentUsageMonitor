# Contributing

Issues are welcome. Before opening one, remove credentials, authorization callback
URLs, account identifiers, private file paths, prompts, responses, private source
code, and raw session or diagnostic records. Use GitHub private vulnerability
reporting for security or privacy vulnerabilities.

Please agree on scope in an issue before starting an implementation pull request.
Unsolicited implementation pull requests may be closed when the direction,
privacy boundary, or verification plan has not been agreed first.

Automated coverage is added only for a reproducible defect: the smallest
deterministic regression test that demonstrates the old failure and protects the
fix. If that test is not feasible, document the manual regression boundary and
why.

Pull requests must use the repository's evidence-rich template and follow
[the evidence contract](docs/development/evidence-rich-pull-requests.md). Include
only the approved scope, distinguish observed evidence from inference, and leave
unexercised states marked unverified.

All changes start from the public repository's current `main`. Before pushing a
feature branch, follow the
[public update workflow](docs/development/public-update-workflow.md): verify commit
identity, inspect the exact public patch, scan new commits, and keep the historical
private repository out of the branch graph.
