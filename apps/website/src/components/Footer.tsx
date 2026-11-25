import { DEVELOPER_URL, REPO_URL } from "../lib/links";
import { DownloadButton } from "./DownloadButton";

export function Footer() {
  return (
    <footer className="mx-auto max-w-5xl px-4 pb-12 text-center sm:px-6">
      <h2 className="heading-5">Set up SQL Server in ten minutes</h2>
      <div className="mt-6">
        <DownloadButton />
      </div>
      <div className="mt-24 flex flex-col items-center gap-2 border-t border-line pt-8">
        <p className="caption-2 text-neutral-400">
          Made by Syntax Lab Technology. Developer{" "}
          <a href={DEVELOPER_URL} className="text-white underline-offset-4 hover:underline">
            Abdul Rafay
          </a>
          .{" "}
          <a href={REPO_URL} className="text-white underline-offset-4 hover:underline">
            Source on GitHub
          </a>
          .
        </p>
        <p className="caption-5 max-w-xl text-neutral-500">
          SQL Server, Visual Studio Code and .NET are trademarks of Microsoft. Docker is a trademark of Docker,
          Inc. SQLPilot is not affiliated with either. No accounts, no tracking.
        </p>
      </div>
    </footer>
  );
}
