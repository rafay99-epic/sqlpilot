const steps = [
  {
    title: "Download and open SQLPilot",
    body: "Drag it to Applications, or just open it and it moves itself there.",
  },
  {
    title: "Press Install",
    body: "SQLPilot installs whatever your Mac is missing. Your Mac asks for its password once, then it takes about 10 minutes.",
  },
  {
    title: "Flip the switch",
    body: "Turn the database on and open the SQL editor: VS Code, already connected, laid out like SSMS from class.",
  },
];

export function Steps() {
  return (
    <section className="mx-auto max-w-5xl px-4 py-24 sm:px-6">
      <h2 className="heading-5 text-center">Ready in three steps</h2>
      <ol className="mt-12 grid gap-8 sm:grid-cols-3">
        {steps.map((step, i) => (
          <li key={step.title}>
            <p className="title-3 text-neutral-500">{i + 1}</p>
            <h3 className="title-2 mt-2">{step.title}</h3>
            <p className="body-6 mt-2 text-neutral-400">{step.body}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
