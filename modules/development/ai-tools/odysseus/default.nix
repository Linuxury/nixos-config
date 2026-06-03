# ===========================================================================
# modules/development/ai-tools/odysseus/default.nix — Odysseus AI workspace
#
# Odysseus is a self-hosted, privacy-first AI workspace with:
#   - Chat + autonomous tool-calling agents
#   - Deep Research (multi-step, source-gathering)
#   - Email assistant via IMAP/SMTP
#   - Persistent memory across sessions
#   - Self-evolving skills library
#   - MCP server support + built-in bash/file/web tools
#   - Side-by-side model comparison
#   - Model cookbook (270+ models with one-click deployment)
#
# Deployment: OCI containers (Podman backend)
#   odysseus  — FastAPI backend + vanilla JS frontend (port 7000)
#   chromadb  — vector store for persistent memory  (port 8100)
#   searxng   — self-hosted search engine           (port 8080)
#   ntfy      — push notifications                  (port 8091)
#
# Status: PLANNED — not yet implemented.
#         See project notes for implementation plan.
#
# Requires:
#   virtualisation.oci-containers.backend = "podman";  (or "docker")
# ===========================================================================

{ ... }:

{
  # Implementation pending.
  # When ready, this will configure virtualisation.oci-containers.containers
  # for odysseus, chromadb, searxng, and ntfy.
}
