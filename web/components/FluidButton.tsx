import type { ButtonHTMLAttributes, ReactNode } from "react";

type FluidButtonVariant = "primary" | "secondary" | "ghost";

interface FluidButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  variant?: FluidButtonVariant;
  loading?: boolean;
}

// Adapted from Fluid Functionalism's registry button: a separate rounded
// background layer carries hover/press motion while the label stays optically
// centred and does not reflow. CSS is local to this project rather than pulling
// in the registry's Tailwind and icon-context dependencies.
export function FluidButton({
  children,
  className = "",
  variant = "primary",
  loading = false,
  disabled,
  ...props
}: FluidButtonProps) {
  return (
    <button
      className={`fluid-button fluid-button--${variant} ${className}`}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      <span className="fluid-button__surface" aria-hidden="true" />
      <span className="fluid-button__content">
        {loading ? <span className="fluid-spinner" aria-hidden="true" /> : null}
        <span className={loading ? "fluid-button__label fluid-button__label--loading" : "fluid-button__label"}>
          {children}
        </span>
      </span>
    </button>
  );
}
