type Meta = { label: string; value: string };

type Props = {
  clubName: string;
  corner: string;          // "Virtual · single use" (preview) or "Shown by the card issuer" (officer)
  pan?: string;            // full number; omitted shows dots + last 4
  last4?: string;
  meta: Meta[];
  variant?: "preview" | "live" | "closed";
  label: string;           // accessible description
};

function group(pan: string) {
  return pan.replace(/\D/g, "").replace(/(.{4})/g, "$1 ").trim();
}

/** Card face from frames 4 (light preview) and 6 (dark, officer). */
export function VirtualCard({ clubName, corner, pan, last4, meta, variant = "preview", label }: Props) {
  return (
    <div className={`cardface${variant === "preview" ? "" : ` ${variant}`}`} role="img" aria-label={label}>
      <div className="top"><span>{clubName}</span><small>{corner}</small></div>
      <div className="pan">{pan ? group(pan) : `•••• •••• •••• ${last4 ?? "••••"}`}</div>
      <div className="meta">
        {meta.map((m) => <div key={m.label}><span>{m.label}</span><b>{m.value}</b></div>)}
      </div>
    </div>
  );
}
