import { useLatestRelease } from "../lib/useLatestRelease";
import { DownloadButton } from "./DownloadButton";

export function Hero() {
  const release = useLatestRelease();
  const meta = [
    "Free",
    "macOS 14 or later",
    "Apple Silicon and Intel",
    release && `Version ${release.version}${release.sizeMB ? `, ${release.sizeMB} MB` : ""}`,
  ].filter(Boolean);

  return (
    <section id="top" className="mx-auto max-w-5xl px-4 pt-16 text-center sm:px-6 sm:pt-24">
      <h1 className="heading-3 sm:heading-1 mx-auto max-w-3xl bg-linear-to-r from-white to-[#9b9b9b] bg-clip-text text-transparent">
        <span className="sm:whitespace-nowrap">SQL Server on your Mac,</span>
        <br />
        ready for class
      </h1>
      <p className="body-3 mx-auto mt-6 max-w-[680px] text-neutral-400">
        SQLPilot sets up SQL Server 2022, Docker and an SSMS style editor with one button. No Terminal,
        no setup guides, no Windows.
      </p>
      <div className="mt-8 flex flex-col items-center gap-3">
        <DownloadButton />
        <p className="caption-5 text-neutral-500">{meta.join(" · ")}</p>
      </div>
      <img
        src={`${import.meta.env.BASE_URL}app.png`}
        alt="The SQLPilot window: SQL Server running, a Connect section with Open SQL Editor and the connection string, and a health check list."
        width={509}
        height={700}
        className="mx-auto mt-16 w-full max-w-[460px] rounded-xl"
      />
      <p className="caption-5 mt-4 text-neutral-500">Signed and notarized by Syntax Lab Technology</p>
    </section>
  );
}
