import { AppleLogo } from "@phosphor-icons/react";
import { DMG_URL } from "../lib/links";

/** The one primary action: the latest notarized DMG from GitHub Releases. */
export function DownloadButton() {
  return (
    <a
      href={DMG_URL}
      className="button-md inline-flex items-center gap-2 rounded-lg bg-white px-3 py-2 text-black transition-[transform,opacity] duration-300 ease-out-soft hover:opacity-90 active:scale-[0.98]"
    >
      <AppleLogo size={20} weight="fill" aria-hidden />
      Download for Mac
    </a>
  );
}
