import { Faq } from "./components/Faq";
import { Footer } from "./components/Footer";
import { Header } from "./components/Header";
import { Hero } from "./components/Hero";
import { Homebrew } from "./components/Homebrew";
import { Steps } from "./components/Steps";

/** One page, one action: download SQLPilot. */
export function App() {
  return (
    <>
      <a href="#main" className="caption-2 sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2">
        Skip to content
      </a>
      <Header />
      <main id="main">
        <Hero />
        <Steps />
        <Homebrew />
        <Faq />
      </main>
      <Footer />
    </>
  );
}
