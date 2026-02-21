import { readFile } from "fs/promises";
import { join } from "path";

// Adjust to your local timezone offset (hours ahead of UTC).
// Examples: Melbourne AEDT = 11, London BST = 1, New York EDT = -4
// Using a positive value means "today" resolves correctly even late at night UTC.
const UTC_OFFSET_HOURS = 11;
const UTC_OFFSET_MS = UTC_OFFSET_HOURS * 60 * 60 * 1000;

function localDateStr(utcNow: Date): string {
  const local = new Date(utcNow.getTime() + UTC_OFFSET_MS);
  return local.toISOString().split("T")[0]; // YYYY-MM-DD
}

const handler = async (event: any): Promise<void> => {
  // Only fire on agent:bootstrap
  if (event.type !== "agent" || event.action !== "bootstrap") return;

  const context = event.context;
  const workspaceDir: string | undefined = context?.workspaceDir;
  if (!workspaceDir || !Array.isArray(context?.bootstrapFiles)) return;

  const memoryDir = join(workspaceDir, "memory");
  const now = new Date();

  const today = localDateStr(now);
  const yesterday = localDateStr(new Date(now.getTime() - 86_400_000));

  for (const dateStr of [today, yesterday]) {
    const filePath = join(memoryDir, `${dateStr}.md`);
    try {
      const content = await readFile(filePath, "utf-8");
      context.bootstrapFiles.push({
        name: `memory/${dateStr}.md`,
        path: filePath,
        content,
        missing: false,
      });
      console.log(
        `[daily-memory] Injected memory/${dateStr}.md (${content.length} chars)`
      );
    } catch {
      // File doesn't exist yet — normal for yesterday/future dates
    }
  }
};

export default handler;
