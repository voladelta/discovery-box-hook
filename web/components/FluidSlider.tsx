import { useId, useState, type CSSProperties } from "react";

interface FluidSliderProps {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  formatValue?: (value: number) => string;
}

// Adapted from Fluid Functionalism's compact slider. This local version keeps
// the native range input for keyboard and assistive-technology support while
// recreating the filled track, expanding thumb and interaction value tooltip.
export function FluidSlider({
  label,
  value,
  onChange,
  min = 0,
  max = 100,
  step = 1,
  formatValue = String,
}: FluidSliderProps) {
  const inputId = useId();
  const [isInteracting, setIsInteracting] = useState(false);
  const clampedValue = Math.max(min, Math.min(max, value));
  const progress = max === min ? 0 : (clampedValue - min) / (max - min);
  const style = { "--slider-progress": `${progress * 100}%` } as CSSProperties;

  return (
    <label
      className={isInteracting ? "fluid-slider fluid-slider--interacting" : "fluid-slider"}
      htmlFor={inputId}
      style={style}
    >
      <span className="fluid-slider__header">
        <span>{label}</span>
        <output htmlFor={inputId}>{formatValue(clampedValue)}</output>
      </span>
      <span className="fluid-slider__control">
        <span className="fluid-slider__track" aria-hidden="true">
          <span className="fluid-slider__fill" />
        </span>
        <span className="fluid-slider__thumb-position" aria-hidden="true">
          <span className="fluid-slider__tooltip">{formatValue(clampedValue)}</span>
          <span className="fluid-slider__thumb" />
        </span>
        <input
          id={inputId}
          type="range"
          min={min}
          max={max}
          step={step}
          value={clampedValue}
          aria-valuetext={formatValue(clampedValue)}
          onChange={(event) => onChange(Number(event.currentTarget.value))}
          onPointerDown={() => setIsInteracting(true)}
          onPointerUp={() => setIsInteracting(false)}
          onPointerCancel={() => setIsInteracting(false)}
          onFocus={() => setIsInteracting(true)}
          onBlur={() => setIsInteracting(false)}
        />
      </span>
    </label>
  );
}
