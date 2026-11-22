import { Color } from 'three';

// Mirrors StadiaColors in lib/ui/tokens.dart (FPL palette).
export const HEX = {
  bg: '#1E0021', // purple120, the page
  dim: '#28002B', // purple110
  free: '#00FF87', // green
  limited: '#FF1B54', // pink-red
  sold: '#7D5980', // purple70
  focus: '#05F0FF', // cyan
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
