import { Badge } from "./Badge";
import { scriptFont, techFont } from "./fonts";
import { DiamondMark, TriangleMark, WingMark } from "./Logos";
import type { JerseyVariant } from "./types";

type Props = {
  id: string;
  variant: JerseyVariant;
  side: "front" | "back";
  width: number;
};

// All coordinates live in a 500x540 viewBox.
const bodyPath = (neckDepth: number) =>
  `M175,28 Q250,${neckDepth} 325,28 L405,50 L482,200 L420,238 L392,190 ` +
  `L398,522 Q250,532 102,522 L108,190 L80,238 L18,200 L95,50 Z`;

const mirror = (points: [number, number][]) =>
  points.map(([x, y]) => [500 - x, y] as [number, number]);

const toPoints = (points: [number, number][]) =>
  points.map((p) => p.join(",")).join(" ");

const RIGHT_CUFF: [number, number][] = [
  [482, 200],
  [420, 238],
  [410, 218],
  [472, 180],
];
const RIGHT_STRIPE: [number, number][] = [
  [318, 30],
  [405, 50],
  [482, 200],
];

const SleeveBadges: React.FC = () => (
  <>
    <g transform="translate(412 118) rotate(6)">
      <Badge width={36} />
    </g>
    <g transform="translate(52 118) rotate(-6)">
      <Badge width={36} />
    </g>
  </>
);

const MagicLogo: React.FC<{ color: string }> = ({ color }) => (
  <g>
    <rect x="112" y="224" width="62" height="54" fill="white" />
    <text
      x="143"
      y="270"
      textAnchor="middle"
      fontFamily="Georgia, 'Times New Roman', serif"
      fontSize="52"
      fill={color}
    >
      M
    </text>
    <text
      x="184"
      y="272"
      fontFamily={techFont}
      fontWeight={500}
      fontSize="52"
      letterSpacing="4"
      fill="none"
      stroke="white"
      strokeWidth="1.6"
    >
      AGIC
    </text>
  </g>
);

const BackSpine: React.FC<{ topMark: React.ReactNode }> = ({ topMark }) => (
  <g>
    <g transform="translate(232 82)">{topMark}</g>
    <path d="M250 126 L251.5 150 L250 152 L248.5 150 Z" fill="white" />
    <g transform="translate(222 158)">
      <WingMark size={56} />
    </g>
    <text
      transform="translate(236 200) rotate(90)"
      fontFamily={techFont}
      fontWeight={700}
      fontSize="46"
      letterSpacing="6"
      fill="white"
    >
      KIVIX
    </text>
    <rect x="248.5" y="352" width="3" height="22" fill="white" />
    <text
      x="250"
      y="402"
      textAnchor="middle"
      fontFamily={techFont}
      fontWeight={700}
      fontSize="28"
      fill="none"
      stroke="white"
      strokeWidth="1.3"
    >
      PRO
    </text>
    <path d="M248.5 414 L251.5 414 L250 490 Z" fill="white" />
  </g>
);

export const Shirt: React.FC<Props> = ({ id, variant, side, width }) => {
  const isFront = side === "front";
  const neckDepth = isFront ? 84 : 46;
  const body = bodyPath(neckDepth);
  const isDynamic = variant.style === "dynamic";

  return (
    <svg
      width={width}
      height={(width * 540) / 500}
      viewBox="0 0 500 540"
      style={{ overflow: "visible", filter: "drop-shadow(0 30px 40px rgba(0,0,0,0.55))" }}
    >
      <defs>
        <clipPath id={`${id}-clip`}>
          <path d={body} />
        </clipPath>
        <linearGradient id={`${id}-shade`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="white" stopOpacity="0.14" />
          <stop offset="0.5" stopColor="white" stopOpacity="0" />
          <stop offset="1" stopColor="black" stopOpacity="0.3" />
        </linearGradient>
        <radialGradient id={`${id}-glow`} cx="0.45" cy="0.35" r="0.6">
          <stop offset="0" stopColor="white" stopOpacity="0.1" />
          <stop offset="1" stopColor="white" stopOpacity="0" />
        </radialGradient>
        <pattern
          id={`${id}-weave`}
          width="18"
          height="18"
          patternUnits="userSpaceOnUse"
          patternTransform="rotate(35)"
        >
          <path d="M0 0 L18 0 M0 9 L9 9" stroke="white" strokeWidth="1" />
        </pattern>
      </defs>

      <path d={body} fill={variant.bodyColor} />

      <g clipPath={`url(#${id}-clip)`}>
        {!isDynamic && (
          <>
            <rect width="500" height="540" fill={`url(#${id}-weave)`} opacity="0.06" />
            <path
              d="M150 60 Q118 300 132 530 M350 60 Q382 300 368 530"
              stroke="rgba(255,255,255,0.14)"
              strokeWidth="2"
              fill="none"
            />
            {!isFront && (
              <path
                d="M60 118 Q250 76 440 118"
                stroke="rgba(255,255,255,0.12)"
                strokeWidth="2"
                fill="none"
              />
            )}
          </>
        )}

        {isDynamic && (
          <>
            {[RIGHT_STRIPE, mirror(RIGHT_STRIPE)].map((pts, i) => (
              <g key={i}>
                <polyline
                  points={toPoints(pts)}
                  stroke={variant.accentColor}
                  strokeWidth="20"
                  fill="none"
                />
                <polyline
                  points={toPoints(pts.map(([x, y]) => [x + (i ? 5 : -5), y + 10]))}
                  stroke="#111"
                  strokeWidth="2.5"
                  fill="none"
                />
              </g>
            ))}
            {[RIGHT_CUFF, mirror(RIGHT_CUFF)].map((pts, i) => (
              <polygon key={i} points={toPoints(pts)} fill={variant.accentColor} />
            ))}
          </>
        )}

        {/* Collar */}
        <path
          d={`M175,28 Q250,${neckDepth} 325,28`}
          stroke={isDynamic ? variant.accentColor : "rgba(0,0,0,0.35)"}
          strokeWidth={isDynamic ? 18 : 10}
          fill="none"
        />

        {/* Fabric shading */}
        <rect width="500" height="540" fill={`url(#${id}-shade)`} />
        <rect width="500" height="540" fill={`url(#${id}-glow)`} />
        <path
          d="M130 330 Q170 420 150 520 M330 300 Q300 400 340 525"
          stroke="rgba(0,0,0,0.07)"
          strokeWidth="18"
          fill="none"
          strokeLinecap="round"
        />
      </g>

      {/* Inner collar shadow */}
      {isFront && (
        <path
          d={`M183,30 Q250,${neckDepth - 14} 317,30 Q250,${neckDepth - 30} 183,30 Z`}
          fill="rgba(0,0,0,0.35)"
        />
      )}

      {!isDynamic && (
        <>
          <g transform="translate(398 70)">
            <DiamondMark size={14} />
          </g>
          <g transform="translate(88 70)">
            <DiamondMark size={14} />
          </g>
        </>
      )}

      {isFront ? (
        <>
          {isDynamic ? (
            <text
              x="250"
              y="132"
              textAnchor="middle"
              fontFamily={scriptFont}
              fontSize="40"
              fill="white"
            >
              Kaiwin
            </text>
          ) : (
            <>
              <g transform="translate(156 104)">
                <TriangleMark size={26} />
              </g>
              <text
                x="169"
                y="146"
                textAnchor="middle"
                fontFamily={techFont}
                fontWeight={700}
                fontSize="12"
                fill="white"
              >
                KAIWIN
              </text>
              <g transform="translate(316 106)">
                <WingMark size={30} />
              </g>
              <text
                x="331"
                y="146"
                textAnchor="middle"
                fontFamily={techFont}
                fontWeight={700}
                fontSize="12"
                fill="white"
              >
                KIVIX
              </text>
            </>
          )}
          <MagicLogo color={variant.bodyColor} />
          <SleeveBadges />
        </>
      ) : (
        <BackSpine
          topMark={isDynamic ? <TriangleMark size={36} /> : <DiamondMark size={36} />}
        />
      )}
    </svg>
  );
};
