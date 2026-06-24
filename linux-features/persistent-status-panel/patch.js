"use strict";

const STORAGE_KEY = "codex-linux-persistent-status-panel-open";

const statusStatePattern =
  /\{conversationId:[^,]+,threadId:[^,]+,rateLimit:[^,]+,onOpenChange:([A-Za-z_$][\w$]*)\}=e,([A-Za-z_$][\w$]*)=[A-Za-z_$][\w$]*\(\),\[([A-Za-z_$][\w$]*),([A-Za-z_$][\w$]*)\]=\(0,([A-Za-z_$][\w$]*)\.useState\)\(!1\),/;

function applyPersistentStatusPanelPatch(source) {
  if (source.includes(STORAGE_KEY)) {
    return source;
  }

  if (!source.includes("composer.statusSlashCommand.description")) {
    return source;
  }

  const match = source.match(statusStatePattern);
  if (!match) {
    console.warn("WARN: Could not find Codex status panel state - skipping persistent status panel patch");
    return source;
  }

  const [stateNeedle, onOpenChange, _intl, _isOpen, setIsOpen] = match;
  const openNeedle = `async()=>{${setIsOpen}(!0),${onOpenChange}?.(!0)}`;
  const closeNeedle = `()=>{${setIsOpen}(!1),${onOpenChange}?.(!1)}`;
  if (!source.includes(openNeedle) || !source.includes(closeNeedle)) {
    console.warn("WARN: Could not find Codex status panel handlers - skipping persistent status panel patch");
    return source;
  }

  const statePatch = stateNeedle.replace(
    ".useState)(!1),",
    `.useState)(()=>{try{return localStorage.getItem(\`${STORAGE_KEY}\`)===\`1\`}catch{return!1}}),`,
  );
  const openPatch = `async()=>{try{localStorage.setItem(\`${STORAGE_KEY}\`,\`1\`)}catch{}${setIsOpen}(!0),${onOpenChange}?.(!0)}`;
  const closePatch = `()=>{try{localStorage.removeItem(\`${STORAGE_KEY}\`)}catch{}${setIsOpen}(!1),${onOpenChange}?.(!1)}`;

  return source
    .replace(stateNeedle, statePatch)
    .replace(openNeedle, openPatch)
    .replace(closeNeedle, closePatch);
}

const patches = [
  {
    id: "composer-status-state",
    phase: "webview-asset",
    order: 20_800,
    ciPolicy: "optional",
    pattern: /^composer-.*\.js$/,
    missingDescription: "composer status panel bundle",
    skipDescription: "persistent status panel patch",
    apply: applyPersistentStatusPanelPatch,
  },
];

module.exports = {
  STORAGE_KEY,
  applyPersistentStatusPanelPatch,
  patches,
};
