# Security and privacy

Do not post credentials, personal paths, account details, private conversations,
or unredacted desktop screenshots in public issues.

Use GitHub's private vulnerability reporting feature when available. If it is
unavailable, request a private reporting channel without posting sensitive
details. Reports should identify the affected revision and a minimal reproduction.

This repository's public snapshot contains selected game source, runtime assets,
documentation and game-only media. Development caches, conversation records,
local settings and raw workstation logs are deliberately excluded.

Run `python tools/validate_public_repo.py` before committing. Automated pattern
checks supplement manual review and do not guarantee discovery of every secret.
