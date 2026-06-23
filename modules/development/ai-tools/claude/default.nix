# ===========================================================================
# modules/development/ai-tools/claude/default.nix — Claude Code + AI Skills
#
# Installs the claude-code CLI and wires the full AI skill environment for
# every HM user on this host via sharedModules — no per-host or per-user
# additions needed. Import this module once, all users get everything.
#
#   ~/.agents/skills      — full agent harness skill library (1332+ skills)
#                           managed by Nix; add a skill by committing to
#                           dotfiles/agents/skills/ and rebuilding.
#
#   ~/.claude/skills/     — Claude Code specific skills (pony-trail, ponytail
#                           family); installed via activation to avoid ~/.claude
#                           symlink conflicts on linuxury's setup.
#
#   ~/.claude/settings.json enabledPlugins — ponytail@DietrichGebert merged in
#                           via activation so all users have it without wiping
#                           their existing settings.
#
# The VSCodium extension config (claudeCode.claudeProcessWrapper) in
# dotfiles/vscodium/settings.json points at the bash wrapper so the
# extension uses the same Nix-installed binary.
#
# Requires: modules/development/ai-tools/default.nix (nix-ld)
# ===========================================================================

{ pkgs, lib, ... }:

let
  # Path is resolved at eval time relative to this file.
  agentsSkillsDir  = ../../../../dotfiles/agents/skills;
  claudeSkillsDir  = ../../../../dotfiles/agents/claude-skills;
in

{
  # =========================================================================
  # System packages — CLI tools available to all users
  # =========================================================================
  environment.systemPackages = [
    pkgs.ponytrail

    # Bash wrapper: claude-code uses bash-specific features that break under sh.
    (pkgs.writeShellScriptBin "claude" ''
      exec env SHELL=${pkgs.bash}/bin/bash ${pkgs.claude-code}/bin/claude "$@"
    '')
  ];

  # =========================================================================
  # Home Manager — applied to every HM user on this host
  # =========================================================================
  home-manager.sharedModules = [
    ({ pkgs, lib, config, ... }: {

      # =====================================================================
      # ~/.agents/skills — full agent harness skill library
      #
      # Migration: if a mutable directory exists from before Nix management,
      # move it to .bak so HM can create the managed symlink cleanly.
      # =====================================================================
      home.activation.migrateAgentsSkills =
        lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          _target="$HOME/.agents/skills"
          if [ -d "$_target" ] && [ ! -L "$_target" ]; then
            $VERBOSE_ECHO "Migrating $_target → $_target.bak (now managed by Nix)"
            mv "$_target" "$_target.bak"
          fi
          unset _target
        '';

      home.file.".agents/skills".source = agentsSkillsDir;

      # =====================================================================
      # ~/.claude/skills — Claude Code specific skills
      #
      # Installed via activation rather than home.file to avoid conflicts
      # with ~/.claude being a symlink to ~/.agents/Claude/ on linuxury.
      # Add new Claude skills as entries in the activation block below.
      # =====================================================================
      home.activation.installClaudeSkills =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _base="$HOME/.claude/skills"
          mkdir -p "$_base"

          # pony-trail — bundled inside the ponytrail Nix package
          if [ ! -d "$_base/pony-trail" ]; then
            $VERBOSE_ECHO "Installing pony-trail skill"
            cp -r ${pkgs.ponytrail}/share/ponytrail/skills/pony-trail/. "$_base/pony-trail/"
          fi

          # ponytail family — committed to dotfiles/agents/claude-skills/
          for _skill in ponytail ponytail-audit ponytail-debt ponytail-help ponytail-review; do
            if [ ! -d "$_base/$_skill" ]; then
              $VERBOSE_ECHO "Installing $_skill skill"
              cp -r ${claudeSkillsDir}/$_skill/. "$_base/$_skill/"
            fi
          done

          unset _base _skill
        '';

      # =====================================================================
      # ~/.claude/settings.json — ensure shared plugins are enabled
      #
      # Merges only the keys we own into an existing settings.json so user-
      # local settings (permissions, MCP servers, theme, etc.) are preserved.
      # Works for linuxury too because ~/.claude is a symlink that the shell
      # resolves at write time.
      # =====================================================================
      home.activation.configureClaudeSettings =
        lib.hm.dag.entryAfter [ "installClaudeSkills" ] ''
          _cfg="$HOME/.claude/settings.json"
          if [ ! -f "$_cfg" ]; then
            printf '{}' > "$_cfg"
          fi
          _tmp=$(${lib.getExe pkgs.jq} \
            '.enabledPlugins["ponytail@DietrichGebert"] = true' \
            "$_cfg")
          printf '%s\n' "$_tmp" > "$_cfg"
          unset _cfg _tmp
        '';

    })
  ];
}
