import { Check, Copy } from "@phosphor-icons/react";
import { useState } from "react";
import { BREW_COMMAND } from "../lib/links";

/** Homebrew install line with a copy button that confirms for a moment. */
export function Homebrew() {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(BREW_COMMAND);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard blocked: the command is selectable text, so it can still be copied by hand.
    }
  };

  return (
    <section className="mx-auto max-w-5xl px-4 pb-24 text-center sm:px-6">
      <h2 className="heading-5">Prefer Homebrew?</h2>
      <div className="mx-auto mt-6 flex max-w-xl items-center gap-2 rounded-lg bg-surface py-2 pr-2 pl-4 text-left">
        <code className="caption-2 min-w-0 flex-1 overflow-x-auto font-mono whitespace-nowrap text-neutral-300 select-all">
          {BREW_COMMAND}
        </code>
        <button
          type="button"
          onClick={copy}
          className="button-sm flex shrink-0 items-center gap-2 rounded-md bg-surface-2 px-3 py-2 transition-[transform,opacity] duration-300 ease-out-soft hover:opacity-80 active:scale-[0.98]"
        >
          {copied ? <Check size={16} aria-hidden /> : <Copy size={16} aria-hidden />}
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
    </section>
  );
}
