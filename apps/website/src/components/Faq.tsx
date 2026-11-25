import { CaretDown } from "@phosphor-icons/react";

const faqs = [
  {
    q: "Do I need SSMS or Windows?",
    a: "No. SSMS only runs on Windows. SQLPilot sets up VS Code's SQL Server extension, which has the same Object Explorer, query editor and results grid.",
  },
  {
    q: "Is it free?",
    a: "Yes. SQLPilot is free, and it installs the free Developer Edition of SQL Server 2022.",
  },
  {
    q: "Will it slow down my Mac?",
    a: "SQL Server gets a fixed share of memory sized to your Mac, starting at 2.5 GB on an 8 GB Mac. Flip the switch off when you are done and the memory comes back.",
  },
  {
    q: "Can I open my professor's .bak or .sql files?",
    a: "Yes. In Terminal, run sqlserver restore with the .bak file, or sqlserver run with the .sql file. Backups made on Windows work.",
  },
  {
    q: "Something broke. What do I do?",
    a: "Open SQLPilot and press Repair. If it still fails, choose Help, then Copy Problem Report, and send it to your teacher. It never includes your password.",
  },
  {
    q: "Which Macs does it support?",
    a: "Apple Silicon and Intel Macs on macOS 14 Sonoma or later, with about 8 GB of free disk space.",
  },
];

export function Faq() {
  return (
    <section className="mx-auto max-w-2xl px-4 pb-24 sm:px-6">
      <h2 className="heading-5 text-center">Questions</h2>
      <div className="mt-8 divide-y divide-line border-y border-line">
        {faqs.map((item) => (
          <details key={item.q} className="group py-4">
            <summary className="title-3 flex cursor-pointer list-none items-center justify-between gap-4">
              {item.q}
              <CaretDown
                size={16}
                aria-hidden
                className="shrink-0 text-neutral-500 transition-transform duration-300 ease-out-soft group-open:rotate-180"
              />
            </summary>
            <p className="body-6 mt-2 text-neutral-400">{item.a}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
