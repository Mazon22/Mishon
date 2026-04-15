import type { LegalDocument } from '../lib/legal-content';

type LegalContentProps = {
  document: LegalDocument;
};

export function LegalContent({ document }: LegalContentProps) {
  return (
    <div className="legal-content">
      <p className="legal-content__intro">{document.intro}</p>

      <div className="legal-content__sections">
        {document.sections.map((section) => (
          <section key={section.title} className="legal-content__section">
            <h3>{section.title}</h3>
            {section.paragraphs.map((paragraph) => (
              <p key={paragraph}>{paragraph}</p>
            ))}
          </section>
        ))}
      </div>
    </div>
  );
}
