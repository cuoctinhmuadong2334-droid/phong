export type JerseyVariant = {
  name: string;
  colorLabel: string;
  style: "dynamic" | "diamond";
  bodyColor: string;
  accentColor: string;
};

export const VARIANTS: JerseyVariant[] = [
  {
    name: "T-SHIRT DYNAMIC",
    colorLabel: "Màu đỏ",
    style: "dynamic",
    bodyColor: "#e3151e",
    accentColor: "#ffffff",
  },
  {
    name: "T-SHIRT DIAMOND",
    colorLabel: "Xanh bộ đội",
    style: "diamond",
    bodyColor: "#0a4a3c",
    accentColor: "#ffffff",
  },
];
