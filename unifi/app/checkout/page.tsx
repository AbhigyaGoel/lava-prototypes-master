import type { Metadata } from "next";
import { CheckoutForm } from "@/components/CheckoutForm";

export const metadata: Metadata = { title: "Test checkout", robots: { index: false } };

// Spec "Mock checkout (new)": stand-in for a real store during the demo. Sandbox only; it can't charge a real card.
export default function Checkout() {
  return (
    <div className="solo">
      <div className="sandbox-band">Unifi test checkout. Works only with Unifi test cards; no real money.</div>
      <div className="solo-body"><CheckoutForm /></div>
    </div>
  );
}
