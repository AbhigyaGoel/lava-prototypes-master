export function PurchaseStatus({ decision }: { decision: "APPROVED" | "DECLINED" }) {
  return decision === "APPROVED"
    ? <span className="pill solid">Approved</span>
    : <span className="pill outline">Declined</span>;
}
