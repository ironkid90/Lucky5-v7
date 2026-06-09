import { GodotWebShell } from "@/components/godot-web-shell";
import { Lucky5Cabinet } from "@/components/lucky5-cabinet";

export const dynamic = "force-dynamic";

export default function HomePage() {
  return <GodotWebShell fallback={<Lucky5Cabinet />} />;
}
