---
description: Save a dated recap of the current OpenCode session
agent: build
---

Create two markdown archives of the current OpenCode conversation and save them locally:

1. a readable recap
2. a detailed diff sidecar with representative code examples

Context for naming and metadata:
- Timestamp: !`date '+%Y-%m-%d_%H-%M-%S'`
- Year/month folder: !`date '+%Y/%m'`
- Project name: !`basename "$PWD"`
- Working directory: !`pwd`
- Git branch: !`git branch --show-current 2>/dev/null || true`
- Optional focus from command arguments: $ARGUMENTS

Requirements:
- Save both files under `~/docs/opencode/YYYY/MM/`.
- Start both filenames with the timestamp above.
- Append a short project slug and a short topic slug, for example: `YYYY-MM-DD_HH-MM-SS_project_topic.md`.
- Use a lowercase hyphenated topic slug. If `$ARGUMENTS` is empty, infer the topic from the conversation.
- Create the destination directory if it does not exist.
- Summarize the current conversation only, so it is easy to revisit later.
- Keep the main recap concise but useful.
- Create the main recap as `..._project_topic.md`.
- Create the detailed sidecar as `..._project_topic_diffs.md`.
- The main recap must include these sections:
  - `# Title`
  - `## Date`
  - `## Project`
  - `## What I was doing`
  - `## Key changes or findings`
  - `## Files, commands, or tools involved`
  - `## Decisions`
  - `## Next steps`
- The sidecar must include these sections:
  - `# Diff Journal`
  - `## Changes that worked`
  - `## Attempts that did not work or were ruled out`
  - `## Representative diff snippets`
  - `## Commands and verification`
- Prefer concrete code and patch examples over prose in the sidecar.
- Include fenced ```diff blocks in the sidecar for the most important edits.
- Capture both successful changes and discarded paths when the conversation contains them.
- If there were no failed patches, explicitly say so and note which hypotheses were ruled out without changing files.
- Reference the sidecar path from the main recap.

After saving the file, reply with:
1. The saved main recap path.
2. The saved diff sidecar path.
3. A short 3-5 bullet recap.
