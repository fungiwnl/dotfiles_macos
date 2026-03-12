import { existsSync } from "node:fs"
import { join } from "node:path"

const sessionTitles = new Map()
const sessionSlugs = new Map()
const lastAgentBySession = new Map()
const lastCompletedAtBySession = new Map()
const lastAlertedAtBySession = new Map()

const HOME = process.env.HOME ?? ""
const SOUND_DIR = join(HOME, ".config", "opencode", "sounds")

const SOUND_BY_KIND = {
  plan: join(SOUND_DIR, "plan.wav"),
  build: join(SOUND_DIR, "build.wav"),
  error: join(SOUND_DIR, "error.wav"),
  default: join(SOUND_DIR, "default.wav"),
}

const FALLBACK_SOUND_BY_KIND = {
  plan: "/System/Library/Sounds/Glass.aiff",
  build: "/System/Library/Sounds/Hero.aiff",
  error: "/System/Library/Sounds/Basso.aiff",
  default: "/System/Library/Sounds/Pop.aiff",
}

const VOICE_BY_KIND = {
  plan: "Daniel",
  build: "Samantha",
  error: "Karen",
  default: "Alex",
}

function cleanText(value) {
  return (value ?? "").replace(/\s+/g, " ").trim()
}

function escapeAppleScript(value) {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
}

function spokenText(value) {
  return cleanText(value)
    .replace(/[_/]/g, " ")
    .replace(/[|]+/g, " ")
    .replace(/\s+/g, " ")
    .slice(0, 140)
}

function normalizeKind(agent) {
  if (agent === "plan") return "plan"
  if (agent === "build") return "build"
  return "default"
}

function sessionLabel(sessionID) {
  if (!sessionID) return "untitled session"
  return cleanText(sessionTitles.get(sessionID)) || cleanText(sessionSlugs.get(sessionID)) || "untitled session"
}

function soundPath(kind) {
  const custom = SOUND_BY_KIND[kind]
  return existsSync(custom) ? custom : FALLBACK_SOUND_BY_KIND[kind]
}

function speechFor(kind, label) {
  const title = spokenText(label)

  if (!title || title === "untitled session") {
    if (kind === "plan") return "Plan finished."
    if (kind === "build") return "Build finished."
    if (kind === "error") return "OpenCode session error."
    return "Session finished."
  }

  if (kind === "plan") return `Plan finished. ${title}.`
  if (kind === "build") return `Build finished. ${title}.`
  if (kind === "error") return `Session error. ${title}.`
  return `Session finished. ${title}.`
}

function subtitleFor(kind) {
  if (kind === "plan") return "Plan complete"
  if (kind === "build") return "Build complete"
  if (kind === "error") return "Session error"
  return "Session complete"
}

async function tryRun(fn) {
  try {
    await fn()
  } catch {}
}

async function notify($, title, subtitle) {
  const script = `display notification "${escapeAppleScript(title)}" with title "OpenCode" subtitle "${escapeAppleScript(subtitle)}"`
  await tryRun(async () => {
    await $`osascript -e ${script}`.quiet()
  })
}

async function play($, kind) {
  await tryRun(async () => {
    await $`afplay ${soundPath(kind)}`.quiet()
  })
}

async function speak($, kind, label) {
  const phrase = speechFor(kind, label)
  await tryRun(async () => {
    await $`say -v ${VOICE_BY_KIND[kind]} ${phrase}`.quiet()
  })
}

export const SessionAlerts = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.created" || event.type === "session.updated") {
        const info = event.properties.info
        sessionTitles.set(info.id, info.title)
        sessionSlugs.set(info.id, info.slug)
        return
      }

      if (event.type === "message.updated") {
        const info = event.properties.info
        if (info.role !== "assistant") return

        lastAgentBySession.set(info.sessionID, info.agent)

        if (info.time.completed) {
          lastCompletedAtBySession.set(info.sessionID, info.time.completed)
        }

        return
      }

      if (event.type === "session.idle") {
        const sessionID = event.properties.sessionID
        const completedAt = lastCompletedAtBySession.get(sessionID)
        if (!completedAt) return
        if (lastAlertedAtBySession.get(sessionID) === completedAt) return

        lastAlertedAtBySession.set(sessionID, completedAt)

        const kind = normalizeKind(lastAgentBySession.get(sessionID))
        const label = sessionLabel(sessionID)

        await notify($, label, subtitleFor(kind))
        await play($, kind)
        await speak($, kind, label)
        return
      }

      if (event.type === "session.error") {
        const label = sessionLabel(event.properties.sessionID)

        await notify($, label, subtitleFor("error"))
        await play($, "error")
        await speak($, "error", label)
      }
    },
  }
}
