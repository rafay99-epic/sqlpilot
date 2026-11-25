import { useEffect, useState } from "react";

export type LatestRelease = { version: string; sizeMB: string };

type GitHubRelease = {
  tag_name: string;
  assets: { name: string; size: number }[];
};

/**
 * Version and DMG size of the newest release, for the line under the download
 * button. Null until loaded, and stays null if GitHub can't be reached or there
 * is no release yet; the button works either way.
 */
export function useLatestRelease(): LatestRelease | null {
  const [release, setRelease] = useState<LatestRelease | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    fetch("https://api.github.com/repos/rafay99-epic/sqlpilot/releases/latest", {
      signal: controller.signal,
    })
      .then((res) => (res.ok ? (res.json() as Promise<GitHubRelease>) : null))
      .then((data) => {
        if (!data) return;
        const dmg = data.assets.find((a) => a.name === "SQLPilot.dmg");
        setRelease({
          version: data.tag_name.replace(/^v/, ""),
          sizeMB: dmg ? (dmg.size / 1_000_000).toFixed(1) : "",
        });
      })
      .catch(() => {});
    return () => controller.abort();
  }, []);

  return release;
}
