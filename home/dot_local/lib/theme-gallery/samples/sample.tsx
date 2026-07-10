// Palette sample: TSX — types, strings, numbers, keywords, JSX, attributes.
import { useState } from "react";

interface Props {
  name?: string;
  retries: number;
}

export function Greeter({ name = "world", retries }: Props): JSX.Element {
  const [count, setCount] = useState<number>(0);
  const label = `hello ${name} (${count}/${retries})`;

  return (
    <button
      className="card"
      disabled={count >= retries}
      onClick={() => setCount((c) => c + 1)}
    >
      {label}
    </button>
  );
}
