# Agents and Skills

Antigravity CLI discovers workspace custom agents under `.agents/agents/` and workspace skills under `.agents/skills/`. Agents use Markdown definitions with YAML frontmatter; skills are directories containing `SKILL.md`.

The project intentionally starts with a small set of agents and skills. New ones should be added only when a recurring workflow or specialized knowledge justifies them.

## Planned evolution

Later experiments may include:
- OCR evaluation skill;
- LLM structured-output skill;
- security review skill;
- backend skill;
- documentation skill;
- a plugin bundling project-specific agent infrastructure.
