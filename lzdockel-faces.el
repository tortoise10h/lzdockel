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
     :foreground "#4a9eff" :weight extra-bold :height 5.0 :inherit fixed-pitch)
    (t
     :foreground "#2563eb" :weight extra-bold :height 5.0 :inherit fixed-pitch))
  "Face for the lzdockel dashboard title."
  :group 'lzdockel-faces)

(defface lzdockel-dashboard-item-dim
  '((((background dark))
     :foreground "#666666")
    (t
     :foreground "#999999"))
  "Face for dimmed/exited dashboard items."
  :group 'lzdockel-faces)

(provide 'lzdockel-faces)
;;; lzdockel-faces.el ends here
