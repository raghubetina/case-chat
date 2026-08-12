import { rm } from "node:fs/promises"
import { build, context } from "esbuild"

const production = process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production"
const watch = process.argv.includes("--watch")
const output = "app/assets/builds/application.js"

const options = {
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  format: "esm",
  minify: production,
  outfile: output,
  publicPath: "/assets",
  sourcemap: production ? false : true,
}

if (production) await rm(`${output}.map`, { force: true })

if (watch) {
  const buildContext = await context(options)
  await buildContext.watch()
  console.log("Watching JavaScript…")
} else {
  await build(options)
}
