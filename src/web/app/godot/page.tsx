import fs from "node:fs";
import path from "node:path";

export const dynamic = "force-dynamic";

export default function GodotCabinetPage() {
  const exportPath = path.join(
    process.cwd(),
    "public",
    "godot-cabinet",
    "index.html",
  );
  const hasGodotExport = fs.existsSync(exportPath);

  return (
    <main className="godot-web-shell" aria-label="Lucky5 Godot cabinet">
      {hasGodotExport ? (
        <iframe
          allow="fullscreen; gamepad; screen-wake-lock"
          allowFullScreen
          className="godot-web-frame"
          src="/godot-cabinet/index.html"
          title="Lucky5 Godot cabinet"
        />
      ) : (
        <section className="godot-web-missing" aria-live="polite">
          <p className="godot-web-kicker">Godot export missing</p>
          <h1>Lucky5 Godot cabinet</h1>
          <p>
            Generate the shared cabinet export before launching this route.
          </p>
          <code>.\scripts\godot\Export-GodotWebCabinet.ps1 -Clean</code>
        </section>
      )}
    </main>
  );
}
