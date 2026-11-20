import {
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import path from "node:path"
import { pathToFileURL } from "node:url"

const root = process.cwd()
const serverDir = path.join(root, ".ssr")
const templatePath = path.join(root, "dist/index.html")

function findServerEntry(directory) {
  const entries = []

  for (const name of readdirSync(directory)) {
    const filePath = path.join(directory, name)
    const stats = statSync(filePath)
    if (stats.isDirectory()) {
      entries.push(...findServerEntry(filePath))
      continue
    }
    if (name === "entry-server.js") {
      entries.push(filePath)
    }
  }

  return entries
}

const serverEntries = findServerEntry(serverDir)
if (serverEntries.length !== 1) {
  throw new Error(`Expected one SSR entry, found ${serverEntries.length}`)
}

const serverModule = await import(pathToFileURL(serverEntries[0]).href)
const appHtml = serverModule.render()
const template = readFileSync(templatePath, "utf8")
const marker = "<!--copyup-app-->"

if (!template.includes(marker) || !template.includes('data-hydrate="false"')) {
  throw new Error("Built index.html is missing the prerender marker")
}

const html = template
  .replace('data-hydrate="false"', 'data-hydrate="true"')
  .replace(marker, appHtml)

writeFileSync(templatePath, html)
rmSync(serverDir, { recursive: true, force: true })
