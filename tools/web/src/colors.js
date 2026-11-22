import { Color } from 'three';

// Mirrors StadiaColors in lib/ui/tokens.dart.
export const HEX = {
  bg: '#071327',
  dim: '#0A1730',
  free: '#5FE0A6',
  limited: '#FFC65C',
  sold: '#41516E',
  focus: '#8DC9FF',
  white: '#FFFFFF',
  lamp: '#FFF1C9',
};

export const PALETTE = Object.fromEntries(
  Object.entries(HEX).map(([k, v]) => [k, new Color(v)]),
);

/** Same thresholds as availabilityColour() in selection_card.dart. */
export function availKey(ratio) {
  if (ratio == null || Number.isNaN(ratio)) return null;
  if (ratio <= 0) return 'sold';
  if (ratio < 0.2) return 'limited';
  return 'free';
}

export const availColor = (ratio) => PALETTE[availKey(ratio)] || null;
export const availCss = (ratio) => HEX[availKey(ratio)] || null;
