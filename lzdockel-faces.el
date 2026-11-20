;;; lzdockel-faces.el --- Face definitions for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(defgroup lzdockel-faces nil
  "Faces used by lzdockel."
  :group 'lzdockel
  :group 'faces
  :prefix "lzdockel-")

(defface lzdockel-status-running
  '((t :inherit success :weight bold))
  "Face for running container status.")

(defface lzdockel-status-exited
  '((t :inherit error))
  "Face for exited/errored container status.")

(defface lzdockel-image-id
  '((t :inherit font-lock-variable-use-face))
  "Face for Docker image IDs.")

(defface lzdockel-dashboard-title
  '((((background dark))
     :foreground "#4a9eff" :weight extra-bold :height 2.5 :inherit fixed-pitch)
    (t
     :foreground "#2563eb" :weight extra-bold :height 2.5 :inherit fixed-pitch))
  "Face for the lzdockel dashboard title."
  :group 'lzdockel-faces)

(defface lzdockel-port
  '((t :inherit font-lock-type-face))
  "Face for container port mappings.")

(defface lzdockel-dashboard-item-dim
  '((((background dark))
     :foreground "#666666")
    (t
     :foreground "#999999"))
  "Face for dimmed/exited dashboard items."
  :group 'lzdockel-faces)

(defface lzdockel-error-badge
  '((((background dark))
     :foreground "#ff6b6b" :weight bold)
    (t
     :foreground "#dc2626" :weight bold))
  "Face for the error status icon and title."
  :group 'lzdockel-faces)

(defface lzdockel-error-heading
  '((((background dark))
     :foreground "#e5e7eb" :weight bold)
    (t
     :foreground "#111827" :weight bold))
  "Face for section headings inside the error card."
  :group 'lzdockel-faces)

(defface lzdockel-error-detail
  '((((background dark))
     :foreground "#9ca3af" :slant italic)
    (t
     :foreground "#6b7280" :slant italic))
  "Face for secondary error details such as daemon stderr."
  :group 'lzdockel-faces)

(defface lzdockel-error-code
  '((((background dark))
     :foreground "#93c5fd" :inherit fixed-pitch)
    (t
     :foreground "#1d4ed8" :inherit fixed-pitch))
  "Face for inline commands or paths in error guidance."
  :group 'lzdockel-faces)

(defface lzdockel-keycap
  '((((background dark))
     :foreground "#f3f4f6" :background "#374151" :weight bold
     :box (:line-width (2 . 1) :color "#4b5563"))
    (t
     :foreground "#1f2937" :background "#e5e7eb" :weight bold
     :box (:line-width (2 . 1) :color "#cbd5e1")))
  "Face for keybinding hints."
  :group 'lzdockel-faces)

(defface lzdockel-hint-label
  '((t :inherit shadow))
  "Face for descriptive labels next to keycaps."
  :group 'lzdockel-faces)

(provide 'lzdockel-faces)
;;; lzdockel-faces.el ends here
