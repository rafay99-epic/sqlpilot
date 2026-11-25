import { GithubLogo } from "@phosphor-icons/react";
import { REPO_URL } from "../lib/links";

export function Header() {
  return (
    <header className="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
      <a href="#top" className="title-3 flex items-center gap-2">
        <img src={`${import.meta.env.BASE_URL}icon.png`} alt="" width={28} height={28} />
        SQLPilot
      </a>
      <a
        href={REPO_URL}
        className="caption-2 flex items-center gap-2 text-neutral-400 transition-opacity duration-300 hover:text-white"
      >
        <GithubLogo size={18} aria-hidden />
        GitHub
      </a>
    </header>
  );
}
