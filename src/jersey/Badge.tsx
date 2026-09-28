import { titleFont } from "../fonts";

// Simplified tournament badge (text-based stand-in for the sponsor patch).
export const Badge: React.FC<{ width: number }> = ({ width }) => {
  const holes = [
    [-14, -10],
    [8, -16],
    [-4, 4],
    [16, 6],
    [-18, 12],
    [4, 20],
  ];
  return (
    <svg width={width} height={width * 1.45} viewBox="0 0 200 290">
      <defs>
        <linearGradient id="badge-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3fbf3a" />
          <stop offset="1" stopColor="#0b6b1f" />
        </linearGradient>
        <radialGradient id="ball" cx="0.35" cy="0.35" r="0.7">
          <stop offset="0" stopColor="#ffe36b" />
          <stop offset="1" stopColor="#c98a00" />
        </radialGradient>
      </defs>
      <rect
        x="6"
        y="6"
        width="188"
        height="278"
        rx="94"
        fill="url(#badge-bg)"
        stroke="#b8f5a0"
        strokeWidth="6"
      />
      <rect
        x="18"
        y="18"
        width="164"
        height="254"
        rx="82"
        fill="none"
        stroke="rgba(255,255,255,0.35)"
        strokeWidth="2"
      />
      <polygon
        points="100,34 106,50 123,50 109,60 114,76 100,66 86,76 91,60 77,50 94,50"
        fill="#e3151e"
      />
      <g transform="translate(100 135)">
        <circle r="44" fill="url(#ball)" />
        {holes.map(([x, y], i) => (
          <circle key={i} cx={x} cy={y} r="5" fill="#5a3b00" opacity="0.8" />
        ))}
      </g>
      <text
        x="100"
        y="205"
        textAnchor="middle"
        fontFamily={titleFont}
        fontWeight={700}
        fontSize="34"
        fill="#ffd21f"
        stroke="#3a2400"
        strokeWidth="1.5"
      >
        PICKLEBALL
      </text>
      <text
        x="100"
        y="233"
        textAnchor="middle"
        fontFamily={titleFont}
        fontWeight={700}
        fontSize="24"
        fill="white"
      >
        WORLD CUP
      </text>
      <text
        x="100"
        y="256"
        textAnchor="middle"
        fontFamily={titleFont}
        fontWeight={700}
        fontSize="18"
        fill="white"
      >
        2026
      </text>
    </svg>
  );
};
